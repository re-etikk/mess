import { NextResponse } from 'next/server';

export async function POST() {
  return NextResponse.json({ success: false, error: 'Manual renewals are disabled until payment verification and persisted audit records are implemented. No entitlement was changed.' }, { status: 503 });
}
