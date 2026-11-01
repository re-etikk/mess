import { NextResponse } from 'next/server';

export async function GET() { return NextResponse.json({ success: false, error: 'Use the persisted /api/provider/plans endpoint.' }, { status: 410 }); }
export async function POST() { return NextResponse.json({ success: false, error: 'Use the persisted /api/provider/plans endpoint.' }, { status: 410 }); }
export async function DELETE() { return NextResponse.json({ success: false, error: 'Use the persisted /api/provider/plans endpoint.' }, { status: 410 }); }
