import { NextRequest, NextResponse } from 'next/server';
import { platformStore, getCurrentMealSlot, generateProviderDailyQR, seedProviderPlansAndMenu } from '@/lib/platform-service';
import { getIndiaDateString } from '@/lib/crypto';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id');

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  let provider = platformStore.providers.get(providerId);

  // If not found in memory, query Supabase database
  if (!provider) {
    try {
      const admin = getAdminClient();
      if (admin) {
        const { data: dbP } = await admin.from('providers').select('*').eq('id', providerId).maybeSingle();
        if (dbP) {
          provider = {
            id: dbP.id,
            owner_user_id: dbP.owner_user_id,
            display_name: dbP.display_name,
            slug: dbP.slug,
            description: dbP.description || 'Homestyle daily meals.',
            phone: dbP.public_phone,
            email: dbP.public_email || `${dbP.slug}@thali.mess`,
            address: `${dbP.address_line1}, ${dbP.locality ? dbP.locality + ', ' : ''}${dbP.city}`,
            locality: dbP.locality || dbP.city,
            city: dbP.city,
            rating: 5.0,
            total_reviews: 0,
            cuisines: ['North Indian', 'Homestyle'],
            dietary_types: ['veg'],
            status: dbP.status,
            created_at: dbP.created_at,
          };
          platformStore.providers.set(provider.id, provider);
          seedProviderPlansAndMenu(provider.id);
        }
      }
    } catch (err) {
      console.warn('Dashboard provider fetch note:', err);
    }
  }

  const currentSlot = getCurrentMealSlot();
  const today = getIndiaDateString();

  const scanStats = platformStore.providerScanCounts.get(providerId) || { total: 0, unbilled: 0 };

  const todayRedemptions = Array.from(platformStore.redemptions.values()).filter(
    (r) => r.provider_id === providerId && r.date === today
  );

  const activePlans = Array.from(platformStore.plans.values()).filter(
    (p) => p.provider_id === providerId && p.is_active
  );

  const activeSubscribers = Array.from(platformStore.subscriptions.values()).filter(
    (s) => s.provider_id === providerId && s.status === 'active'
  );

  const qrData = generateProviderDailyQR({
    providerId,
    slot: currentSlot,
  });

  return NextResponse.json({
    success: true,
    provider: provider || null,
    today_date: today,
    current_slot: currentSlot,
    qr_token: qrData.token,
    metrics: {
      today_scans_count: todayRedemptions.length,
      total_scans: scanStats.total,
      unbilled_scans: scanStats.unbilled,
      active_subscribers: activeSubscribers.length,
      active_plans_count: activePlans.length,
    },
    today_redemptions: todayRedemptions.slice(0, 15),
  });
}
