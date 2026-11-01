import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json({ success: false, error: 'Subscriber history is unavailable until the database redemption transaction is enabled.' }, { status: 503 });
}
