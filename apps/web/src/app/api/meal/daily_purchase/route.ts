import { NextResponse } from 'next/server';

/** Single-meal entitlement is created only by the verified payment webhook. */
export async function POST() {
  return NextResponse.json({
    success: false,
    code: 'payments_not_configured',
    error: 'Single-meal purchases are temporarily unavailable. No payment or entitlement was created.',
  }, { status: 503, headers: { 'Cache-Control': 'no-store' } });
}
