import { NextResponse } from 'next/server';

export async function GET() { return NextResponse.json({ error: 'Subscription records are unavailable until the authenticated database is configured.' }, { status: 503 }); }
export async function POST() { return NextResponse.json({ error: 'Subscription activation requires verified payment and a durable database transaction.' }, { status: 503 }); }
