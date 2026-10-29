import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';

  const plans = Array.from(platformStore.plans.values()).filter(
    (p) => p.provider_id === providerId
  );

  return NextResponse.json({
    success: true,
    plans,
  });
}
