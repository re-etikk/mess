import { NextResponse } from 'next/server';

/** Manual enrollment cannot create accounts or entitlements without a durable consent/payment flow. */
export async function POST() {
  return NextResponse.json({
    success: false,
    code: 'manual_enrollment_unavailable',
    error: 'Manual member enrollment is not configured. No account, password, or subscription was created.',
  }, { status: 503 });
}
