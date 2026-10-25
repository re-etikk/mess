import { NextRequest, NextResponse } from 'next/server';
import { verifyWebhookSignature } from '@/lib/crypto';
import { platformStore } from '@/lib/platform-service';

export async function POST(req: NextRequest) {
  try {
    const rawBody = await req.text();
    const signature = req.headers.get('x-razorpay-signature') || '';
    const secret = process.env.RAZORPAY_WEBHOOK_SECRET || 'test-only-webhook-secret';

    if (signature && secret) {
      const isValid = verifyWebhookSignature(rawBody, signature, secret);
      if (!isValid) {
        return NextResponse.json({ error: 'Invalid webhook signature.' }, { status: 400 });
      }
    }

    let event: any = {};
    try {
      event = JSON.parse(rawBody);
    } catch {
      return NextResponse.json({ error: 'Malformed JSON payload.' }, { status: 400 });
    }

    const eventType = event.event || 'payment.captured';
    const payload = event.payload || {};

    if (eventType === 'payment.captured') {
      const payment = payload.payment?.entity;
      const orderId = payment?.order_id;
      if (orderId) {
        for (const sub of platformStore.subscriptions.values()) {
          if (sub.razorpay_payment_id === orderId || sub.razorpay_payment_id === payment?.id) {
            sub.status = 'active';
          }
        }
      }
    } else if (eventType === 'subscription.charged') {
      const subEntity = payload.subscription?.entity;
      if (subEntity?.id) {
        const sub = platformStore.subscriptions.get(subEntity.id);
        if (sub) {
          sub.status = 'active';
        }
      }
    }

    return NextResponse.json({
      received: true,
      event: eventType,
      timestamp: new Date().toISOString(),
    });
  } catch (err: any) {
    return NextResponse.json(
      { error: err.message || 'Webhook processing failed' },
      { status: 500 }
    );
  }
}
