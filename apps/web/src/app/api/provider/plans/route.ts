import { NextRequest, NextResponse } from 'next/server';
import { platformStore, seedProviderPlansAndMenu } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';

  let plans = Array.from(platformStore.plans.values()).filter(
    (p) => p.provider_id === providerId
  );

  if (plans.length === 0) {
    seedProviderPlansAndMenu(providerId);
    plans = Array.from(platformStore.plans.values()).filter(
      (p) => p.provider_id === providerId
    );
  }

  return NextResponse.json({
    success: true,
    plans,
  });
}
