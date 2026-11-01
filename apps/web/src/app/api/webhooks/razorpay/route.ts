import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

/**
 * Payment confirmation is deliberately disabled until signature validation,
 * event idempotency, amount matching, and entitlement activation can be
 * processed atomically against the canonical payment_status enum.
 */
export async function POST() {
  return NextResponse.json({
    success: false,
    error: 'Payment webhook processing is temporarily unavailable. No payment or entitlement state was changed.',
  }, { status: 503, headers: { 'Cache-Control': 'no-store' } });
}
