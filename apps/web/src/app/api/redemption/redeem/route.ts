import { NextResponse } from 'next/server';

/** Provider-side redemption must use verified staff identity and a database transaction. */
export async function POST() {
  return NextResponse.json(
    { error: 'Meal redemption is unavailable until authenticated database transactions are configured.' },
    { status: 503 },
  );
}
