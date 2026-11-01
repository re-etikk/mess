import { NextResponse } from 'next/server';

/** No entitlement may be created until a verified payment order + webhook flow is configured. */
export async function POST() {
  return NextResponse.json({
    success: false,
    code: 'payments_not_configured',
    error: 'Online purchases are temporarily unavailable. No subscription or payment was created.',
  }, { status: 503, headers: { 'Cache-Control': 'no-store' } });
}
