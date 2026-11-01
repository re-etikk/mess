import { NextResponse } from 'next/server';

export async function GET() { return NextResponse.json({ success: false, error: 'Reviews are unavailable because the connected schema has no persisted provider review table.' }, { status: 503 }); }
export async function POST() { return NextResponse.json({ success: false, error: 'Review was not saved; persisted provider reviews are not configured.' }, { status: 503 }); }
