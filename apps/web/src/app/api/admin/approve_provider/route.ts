import { NextRequest, NextResponse } from 'next/server';
import { requireAdmin } from '@/lib/supabase/admin';

/** Legacy endpoint kept for older clients; it deliberately performs no parallel/fallback mutation. */
export async function POST(req: NextRequest) {
  const auth = await requireAdmin(req);
  if (!auth.ok) return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  return NextResponse.json({ success: false, error: 'This endpoint is retired. Use PATCH /api/admin/providers.' }, { status: 410 });
}
