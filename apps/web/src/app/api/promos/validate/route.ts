import { NextResponse } from 'next/server';

export async function POST() {
  return NextResponse.json({ isValid: false, code: 'promotions_not_configured', message: 'Promotions cannot be validated until persisted promotion rules and checkout are enabled.' }, { status: 503 });
}
