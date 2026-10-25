import { NextResponse } from 'next/server';

/** Redemption must be authenticated and transactionally persisted before it can be enabled. */
export async function POST() {
  return NextResponse.json(
    { error: 'Meal redemption is unavailable until authenticated database transactions are configured.' },
    { status: 503 },
  );
}
