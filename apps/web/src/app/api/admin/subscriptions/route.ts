import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export async function GET(req: NextRequest) {
  const subs = Array.from(platformStore.subscriptions.values());
  return NextResponse.json({
    success: true,
    total: subs.length,
    active: subs.filter((s) => s.status === 'active').length,
    subscriptions: subs,
  });
}
