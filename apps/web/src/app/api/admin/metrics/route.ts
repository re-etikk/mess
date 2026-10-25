import { NextResponse } from 'next/server';

export async function GET() { return NextResponse.json({ error: 'Admin metrics require server-managed admin authorization and live data.' }, { status: 503 }); }
