import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';

  const subs = Array.from(platformStore.subscriptions.values()).filter(
    (s) => s.provider_id === providerId
  );

  return NextResponse.json({
    success: true,
    total: subs.length,
    active_count: subs.filter((s) => s.status === 'active').length,
    subscriptions: subs,
  });
}
