import { NextResponse } from 'next/server';

/** The live schema has no counter-orders table; never report an in-memory order as paid. */
export async function GET() {
  return NextResponse.json({ success: false, error: 'Counter-order records are not configured in the connected database.' }, { status: 503 });
}

export async function POST() {
  return NextResponse.json({ success: false, error: 'Counter-order recording is unavailable until a persistent, audited order table is configured. No order was recorded.' }, { status: 503 });
}
