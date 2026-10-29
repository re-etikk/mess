import { NextRequest, NextResponse } from 'next/server';
import { platformStore, ProviderTimingsData } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';

  let timings = platformStore.timings.get(providerId);
  if (!timings) {
    timings = {
      provider_id: providerId,
      breakfast: { enabled: true, start: '07:30', end: '10:00' },
      lunch: { enabled: true, start: '11:30', end: '15:00' },
      dinner: { enabled: true, start: '19:30', end: '22:30' },
      weekly_off: 'None (Open 7 Days)',
      updated_at: new Date().toISOString(),
    };
    platformStore.timings.set(providerId, timings);
  }

  return NextResponse.json({
    success: true,
    timings,
  });
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = body.provider_id || 'prov-radhe-001';

    const timings: ProviderTimingsData = {
      provider_id: providerId,
      breakfast: body.breakfast || { enabled: true, start: '07:30', end: '10:00' },
      lunch: body.lunch || { enabled: true, start: '11:30', end: '15:00' },
      dinner: body.dinner || { enabled: true, start: '19:30', end: '22:30' },
      weekly_off: body.weekly_off || 'None (Open 7 Days)',
      updated_at: new Date().toISOString(),
    };

    platformStore.timings.set(providerId, timings);

    return NextResponse.json({
      success: true,
      timings,
      message: '✅ Operating hours updated successfully!',
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Failed to update timings' },
      { status: 500 }
    );
  }
}
