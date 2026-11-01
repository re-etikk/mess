import { NextResponse } from 'next/server';

/** Retired: client-supplied booking details cannot mint a redeemable QR. */
export async function POST() {
  return NextResponse.json({
    success: false,
    code: 'secure_redemption_unavailable',
    error: 'QR issuance is disabled until the atomic, database-backed redemption flow is installed.',
  }, { status: 503, headers: { 'Cache-Control': 'no-store' } });
}
