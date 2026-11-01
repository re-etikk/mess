import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id') || params.get('providerId') || '';

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const db = getAdminClient();
  if (!db) {
    return NextResponse.json({ success: false, error: 'Reports data service is not configured.' }, { status: 503 });
  }

  try {
    const today = new Date();
    const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate()).toISOString();

    const [subsResult, todayRedemptionsResult, allRedemptionsResult] = await Promise.all([
      db
        .from('subscriptions')
        .select('id,status,plan_type_snapshot,remaining_meal_credits')
        .eq('provider_id', providerId),
      db
        .from('meal_redemptions')
        .select('id', { count: 'exact', head: true })
        .eq('provider_id', providerId)
        .gte('redeemed_at', todayStart),
      db
        .from('meal_redemptions')
        .select('id,redeemed_at')
        .eq('provider_id', providerId)
        .order('redeemed_at', { ascending: false })
        .limit(100),
    ]);

    if (subsResult.error) throw subsResult.error;

    const subscriptions = subsResult.data ?? [];
    const activeSubscribers = subscriptions.filter((s) => s.status === 'active').length;
    const expiredSubscribers = subscriptions.filter((s) => s.status === 'expired').length;
    const totalRedemptionsToday = todayRedemptionsResult.count ?? 0;
    const totalRedemptionsRecorded = (allRedemptionsResult.data ?? []).length;

    return NextResponse.json(
      {
        success: true,
        summary: {
          active_subscribers: activeSubscribers,
          expired_subscribers: expiredSubscribers,
          total_subscriptions_recorded: subscriptions.length,
          redemptions_today: totalRedemptionsToday,
          total_redemptions_recorded: totalRedemptionsRecorded,
        },
        recent_activity: allRedemptionsResult.data ?? [],
      },
      { headers: { 'Cache-Control': 'private, no-store' } }
    );
  } catch (error) {
    console.error('Provider reports query failed:', error instanceof Error ? error.message : 'unknown');
    return NextResponse.json({ success: false, error: 'Reports could not be compiled.' }, { status: 503 });
  }
}
