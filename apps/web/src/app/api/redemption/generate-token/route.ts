import { NextResponse } from 'next/server';

export async function POST() { return NextResponse.json({ error: 'Customer QR issuance requires an authenticated customer and a live entitlement.' }, { status: 503 }); }
