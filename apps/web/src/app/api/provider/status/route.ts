import { NextRequest, NextResponse } from 'next/server';
import { platformStore, updateProviderStatus, isProviderOpen } from '@/lib/platform-service';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('providerId') || searchParams.get('provider_id');

  if (!providerId) {
    return NextResponse.json({ error: 'providerId is required' }, { status: 400 });
  }

  const isOpen = isProviderOpen(providerId);
  const provider = platformStore.providers.get(providerId);

  return NextResponse.json({
    provider_id: providerId,
    display_name: provider?.display_name || 'Kitchen Partner',
    is_open_today: isOpen,
    status_label: isOpen ? 'OPEN / SERVING TODAY' : 'CLOSED / OFF TODAY',
  });
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = body.provider_id || body.providerId;
    const isOpen = Boolean(body.is_open ?? body.isOpen);

    if (!providerId) {
      return NextResponse.json({ error: 'provider_id is required' }, { status: 400 });
    }

    updateProviderStatus(providerId, isOpen);

    // Also update Supabase if configured
    try {
      const admin = getAdminClient();
      if (admin) {
        await admin
          .from('providers')
          .update({ is_open_today: isOpen } as any)
          .eq('id', providerId);
      }
    } catch {
      // In-memory store handles it
    }

    return NextResponse.json({
      success: true,
      provider_id: providerId,
      is_open_today: isOpen,
      message: isOpen
        ? '🟢 Kitchen is now marked OPEN & SERVING TODAY. Students can scan and claim meals.'
        : '🔴 Kitchen is now marked CLOSED / OFF TODAY. Dark shade applied and scans are paused.',
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message || 'Failed to update status' }, { status: 500 });
  }
}
