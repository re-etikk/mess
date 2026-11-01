import { NextResponse } from 'next/server';

/** No announcements table exists in the verified live schema. */
export async function GET() {
  return NextResponse.json({ success: false, error: 'Announcements are unavailable because this feature has no persisted backend table yet.' }, { status: 503 });
}
