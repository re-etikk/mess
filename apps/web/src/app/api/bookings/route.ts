import { NextResponse } from 'next/server';

export async function GET() { return NextResponse.json({ error: 'Booking records are unavailable until the authenticated database is configured.' }, { status: 503 }); }
export async function POST() { return NextResponse.json({ error: 'Booking creation is unavailable until server-side entitlement checks and database transactions are configured.' }, { status: 503 }); }
