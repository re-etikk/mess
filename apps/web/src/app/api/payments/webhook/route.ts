import { NextResponse } from 'next/server';

/** Compatibility endpoint: payment events must be durably verified before acknowledgement. */
export async function POST() {
  return NextResponse.json({ error: 'Payment webhook processing is not configured; no entitlement was changed.' }, { status: 503 });
}
