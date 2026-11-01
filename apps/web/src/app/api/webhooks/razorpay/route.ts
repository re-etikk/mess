import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;
  if (!webhookSecret) {
    return NextResponse.json(
      { error: 'Payment webhook is not configured (missing RAZORPAY_WEBHOOK_SECRET).' },
      { status: 503 }
    );
  }

  const signature = req.headers.get('x-razorpay-signature');
  if (!signature) {
    return NextResponse.json({ error: 'Missing x-razorpay-signature header.' }, { status: 400 });
  }

  let rawBody: string;
  try {
    rawBody = await req.text();
  } catch {
    return NextResponse.json({ error: 'Failed to read request body.' }, { status: 400 });
  }

  // 1. Cryptographic HMAC-SHA256 signature verification
  const expectedSignature = crypto
    .createHmac('sha256', webhookSecret)
    .update(rawBody)
    .digest('hex');

  const signatureValid = crypto.timingSafeEqual(
    Buffer.from(signature, 'utf8'),
    Buffer.from(expectedSignature, 'utf8')
  );

  if (!signatureValid) {
    console.warn('Razorpay webhook signature verification failed.');
    return NextResponse.json({ error: 'Invalid webhook signature.' }, { status: 400 });
  }

  let eventPayload: any;
  try {
    eventPayload = JSON.parse(rawBody);
  } catch {
    return NextResponse.json({ error: 'Invalid JSON payload.' }, { status: 400 });
  }

  const eventType: string = eventPayload.event || 'unknown';
  const eventId: string = eventPayload.entity?.id || eventPayload.payload?.payment?.entity?.id || `evt_${Date.now()}`;

  const db = getAdminClient();
  if (!db) {
    return NextResponse.json(
      { error: 'Server database client is not configured for webhook processing.' },
      { status: 503 }
    );
  }

  // 2. Idempotency Check via payment_webhook_events
  try {
    const { data: existingEvent } = await db
      .from('payment_webhook_events')
      .select('id,processing_status')
      .eq('gateway_name', 'razorpay')
      .eq('gateway_event_id', eventId)
      .maybeSingle();

    if (existingEvent) {
      // Event already recorded and handled
      return NextResponse.json(
        { success: true, message: 'Event already processed (idempotent).', event_id: eventId },
        { status: 200 }
      );
    }

    // Record incoming webhook event
    await db.from('payment_webhook_events').insert({
      gateway_name: 'razorpay',
      gateway_event_id: eventId,
      event_type: eventType,
      signature_verified: true,
      processing_status: 'processing',
      sanitized_payload: {
        event: eventType,
        id: eventId,
        contains_payment: Boolean(eventPayload.payload?.payment),
        contains_order: Boolean(eventPayload.payload?.order),
      },
    });

    // 3. Process payment confirmation events: payment.captured, order.paid
    if (eventType === 'payment.captured' || eventType === 'order.paid') {
      const paymentEntity = eventPayload.payload?.payment?.entity;
      const orderEntity = eventPayload.payload?.order?.entity;
      const gatewayOrderId = paymentEntity?.order_id || orderEntity?.id;
      const gatewayPaymentId = paymentEntity?.id;
      const amountPaise = paymentEntity?.amount || orderEntity?.amount;

      if (gatewayOrderId) {
        // Find matching transaction in payment_transactions
        const { data: txn } = await db
          .from('payment_transactions')
          .select('id,customer_id,subscription_id,booking_id,purpose,status')
          .eq('gateway_name', 'razorpay')
          .eq('gateway_order_id', gatewayOrderId)
          .maybeSingle();

        if (txn) {
          // Update transaction to paid
          await db
            .from('payment_transactions')
            .update({
              status: 'paid',
              gateway_payment_id: gatewayPaymentId || null,
              verified_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            })
            .eq('id', txn.id);

          // Activate entitlement only upon verified payment
          if (txn.purpose === 'subscription_purchase' && txn.subscription_id) {
            await db
              .from('subscriptions')
              .update({
                status: 'active',
                updated_at: new Date().toISOString(),
              })
              .eq('id', txn.subscription_id);
          } else if (txn.purpose === 'single_meal_purchase' && txn.booking_id) {
            await db
              .from('meal_bookings')
              .update({
                status: 'confirmed',
                updated_at: new Date().toISOString(),
              })
              .eq('id', txn.booking_id);
          }
        }
      }
    }

    // Mark webhook event processed
    await db
      .from('payment_webhook_events')
      .update({
        processing_status: 'processed',
        processed_at: new Date().toISOString(),
      })
      .eq('gateway_name', 'razorpay')
      .eq('gateway_event_id', eventId);

    return NextResponse.json({ success: true, processed: true }, { status: 200 });
  } catch (error) {
    console.error('Webhook processing failure:', error instanceof Error ? error.message : 'unknown');
    // Mark failed in event table if possible
    try {
      await db
        .from('payment_webhook_events')
        .update({
          processing_status: 'failed',
          failure_code: error instanceof Error ? error.message.slice(0, 100) : 'PROCESSING_ERROR',
        })
        .eq('gateway_name', 'razorpay')
        .eq('gateway_event_id', eventId);
    } catch {}

    return NextResponse.json({ error: 'Webhook processing encountered an error.' }, { status: 500 });
  }
}
