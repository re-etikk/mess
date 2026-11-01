import { NextResponse } from 'next/server';

/** Renewal must go through a verified payment transaction; never extend access from request data. */
export async function POST() {
  return NextResponse.json({
    success: false,
    code: 'payments_not_configured',
    error: 'Renewals are temporarily unavailable. No subscription was changed.',
  }, { status: 503, headers: { 'Cache-Control': 'no-store' } });
}
