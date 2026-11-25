import { NextRequest, NextResponse } from 'next/server';
import {
  fetchCashfreeOrder,
  fetchCashfreeOrderPayments,
  getCashfreeConfig,
} from '@/lib/cashfree';
import { fulfillCashfreePaidOrder } from '@/lib/cashfree-fulfillment';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const cfg = getCashfreeConfig();
    if (!cfg.configured) {
      return NextResponse.json(
        {
          success: false,
          code: 'cashfree_not_configured',
          error: 'Cashfree Payment Gateway is not configured on the server.',
        },
        { status: 503 },
      );
    }

    const body = await req.json().catch(() => ({}));
    const orderId = (body.order_id || body.orderId || '').trim();
    if (!orderId) {
      return NextResponse.json(
        { success: false, error: 'order_id is required.' },
        { status: 400 },
      );
    }

    // Authoritative server-side verification against Cashfree Orders API
    const cfOrder = await fetchCashfreeOrder(orderId);
    const status = (cfOrder.order_status || '').toUpperCase();

    if (status !== 'PAID') {
      return NextResponse.json(
        {
          success: false,
          order_id: orderId,
          order_status: status,
          error:
            status === 'ACTIVE'
              ? 'Payment is still pending or was not completed.'
              : `Payment was not completed (Status: ${status}).`,
        },
        { status: 402 },
      );
    }

    const payments = await fetchCashfreeOrderPayments(orderId);
    const successPayment = payments.find(
      (p: any) => String(p?.payment_status || '').toUpperCase() === 'SUCCESS',
    );
    const cfPaymentId = successPayment?.cf_payment_id
      ? String(successPayment.cf_payment_id)
      : undefined;

    const result = await fulfillCashfreePaidOrder({
      orderId: cfOrder.order_id,
      cfOrderId: cfOrder.cf_order_id ? String(cfOrder.cf_order_id) : undefined,
      cfPaymentId,
      orderAmountInr: Number(cfOrder.order_amount),
      orderTags: cfOrder.order_tags,
    });

    return NextResponse.json({
      success: true,
      verified: true,
      order_id: cfOrder.order_id,
      order_status: status,
      cf_payment_id: cfPaymentId || null,
      amount_inr: result.amountInr,
      purpose: result.purpose,
      subscription: result.subscription || null,
      already_processed: result.alreadyProcessed,
      message: 'Payment verified and pass activated!',
    });
  } catch (err: any) {
    console.error('Cashfree verify error:', err);
    return NextResponse.json(
      {
        success: false,
        error: err?.message || 'Unable to verify Cashfree payment.',
      },
      { status: 500 },
    );
  }
}
