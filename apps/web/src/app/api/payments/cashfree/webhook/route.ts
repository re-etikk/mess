import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import {
  getCashfreeConfig,
  verifyCashfreeWebhookSignature,
} from '@/lib/cashfree';
import { fulfillCashfreePaidOrder } from '@/lib/cashfree-fulfillment';

export const dynamic = 'force-dynamic';

export async function handleCashfreeWebhook(req: NextRequest) {
  const cfg = getCashfreeConfig();
  if (!cfg.configured) {
    return NextResponse.json(
      {
        success: false,
        error: 'Cashfree webhook secret is not configured; no entitlement was changed.',
      },
      { status: 503 },
    );
  }

  // IMPORTANT: Read raw text body before parsing JSON for HMAC-SHA256 verification
  const rawBody = await req.text();
  const signature = req.headers.get('x-webhook-signature');
  const timestamp = req.headers.get('x-webhook-timestamp');

  const isValid = verifyCashfreeWebhookSignature(rawBody, signature, timestamp);
  if (!isValid) {
    return NextResponse.json(
      { success: false, error: 'Invalid Cashfree webhook signature.' },
      { status: 400 },
    );
  }

  let payload: any;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return NextResponse.json(
      { success: false, error: 'Invalid JSON payload.' },
      { status: 400 },
    );
  }

  const eventType = String(payload?.event_type || payload?.type || 'UNKNOWN');
  const order = payload?.data?.order || {};
  const payment = payload?.data?.payment || {};
  const orderId = String(order?.order_id || '');
  const cfPaymentId = payment?.cf_payment_id ? String(payment.cf_payment_id) : '';
  const eventId = `${eventType}_${orderId}_${cfPaymentId || timestamp || Date.now()}`;

  const admin = getAdminClient();
  if (admin) {
    try {
      await admin.from('payment_webhook_events').upsert(
        {
          gateway_name: 'cashfree',
          gateway_event_id: eventId,
          event_type: eventType,
          signature_verified: true,
          processing_status: 'received',
          sanitized_payload: {
            order_id: orderId,
            payment_status: payment?.payment_status || null,
            payment_amount: payment?.payment_amount || order?.order_amount || null,
          },
        },
        { onConflict: 'gateway_name,gateway_event_id' },
      );
    } catch (e) {
      console.warn('Webhook audit insert warning:', e);
    }
  }

  if (
    eventType === 'PAYMENT_SUCCESS_WEBHOOK' ||
    String(payment?.payment_status || '').toUpperCase() === 'SUCCESS'
  ) {
    if (orderId) {
      try {
        await fulfillCashfreePaidOrder({
          orderId,
          cfOrderId: order?.cf_order_id ? String(order.cf_order_id) : undefined,
          cfPaymentId: cfPaymentId || undefined,
          orderAmountInr: Number(order?.order_amount || payment?.payment_amount || 0),
          orderTags: order?.order_tags,
        });

        if (admin) {
          await admin
            .from('payment_webhook_events')
            .update({
              processing_status: 'processed',
              processed_at: new Date().toISOString(),
            })
            .eq('gateway_name', 'cashfree')
            .eq('gateway_event_id', eventId);
        }
      } catch (err: any) {
        console.error('Cashfree webhook fulfillment error:', err);
        if (admin) {
          await admin
            .from('payment_webhook_events')
            .update({
              processing_status: 'failed',
              failure_code: err?.message?.slice(0, 120) || 'fulfillment_error',
            })
            .eq('gateway_name', 'cashfree')
            .eq('gateway_event_id', eventId);
        }
        return NextResponse.json(
          { success: false, error: 'Fulfillment failed.' },
          { status: 500 },
        );
      }
    }
  } else if (
    eventType === 'PAYMENT_FAILED_WEBHOOK' ||
    eventType === 'PAYMENT_USER_DROPPED_WEBHOOK'
  ) {
    if (admin && orderId) {
      try {
        await admin
          .from('payment_transactions')
          .update({
            status: eventType === 'PAYMENT_USER_DROPPED_WEBHOOK' ? 'cancelled' : 'failed',
            failure_code: payment?.payment_message || eventType,
          })
          .eq('gateway_name', 'cashfree')
          .eq('gateway_order_id', orderId);
      } catch {}
    }
  }

  return NextResponse.json({ success: true, received: true, event_type: eventType });
}

export async function POST(req: NextRequest) {
  return handleCashfreeWebhook(req);
}
