import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id');

  let list = Array.from(platformStore.announcements.values()).filter((a) => a.is_active);
  if (providerId) {
    list = list.filter((a) => !a.provider_id || a.provider_id === providerId);
  }

  return NextResponse.json({
    success: true,
    announcements: list,
  });
}
