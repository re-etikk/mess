import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';
import { requireAdmin } from '@/lib/supabase/admin';

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }

  const subs = Array.from(platformStore.subscriptions.values());
  return NextResponse.json({
    success: true,
    total: subs.length,
    active: subs.filter((s) => s.status === 'active').length,
    subscriptions: subs,
  });
}
