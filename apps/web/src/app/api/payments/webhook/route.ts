import { NextResponse } from 'next/server';

/** No payment event is acknowledged until signature verification and durable idempotency exist. */
export async function POST() {
  return NextResponse.json(
    { error: 'Payment webhook processing is unavailable until verified provider credentials and durable database processing are configured.' },
    { status: 503 },
  );
}
