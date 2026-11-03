import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { getCurrentMealSlot, platformStore } from '@/lib/platform-service';
import { generateCounterQRToken, getIndiaDateString } from '@/lib/crypto';
import { requireProviderOwnership } from '@/lib/provider-auth';

export async function issueProviderQr(req: NextRequest, providerId: string | null, slot: string | null) {
  if (!providerId) return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  const mealSlot = (slot || getCurrentMealSlot() || 'LUNCH').toUpperCase();
  if (mealSlot.length > 40) return NextResponse.json({ success: false, error: 'Invalid meal slot.' }, { status: 400 });

  const db = getAdminClient();
  let providerExistsAndActive = false;

  if (db) {
    try {
      const { data: provider } = await db.from('providers').select('id,status').eq('id', providerId).maybeSingle();
      if (provider) {
        if (provider.status !== 'active' && provider.status !== 'approved') {
          return NextResponse.json({ success: false, error: 'A QR code is available only after the provider is active.' }, { status: 403 });
        }
        providerExistsAndActive = true;
      }
    } catch {}
  }

  const inStore = platformStore.providers.get(providerId);
  if (inStore && inStore.status === 'active') {
    providerExistsAndActive = true;
  }

  const access = await requireProviderOwnership(req, providerId);
  // Allow if requester is authenticated OR if target mess is a confirmed active/approved mess
  if (!access.ok && !providerExistsAndActive) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const date = getIndiaDateString();

  try {
    if (db) {
      // Check or ensure meal slot exists in db
      const { data: existingSlots } = await db.from('meal_slots').select('id,name').eq('provider_id', providerId).ilike('name', mealSlot).limit(1);
      if (!existingSlots || existingSlots.length === 0) {
        const starts = mealSlot === 'BREAKFAST' ? '07:30:00' : (mealSlot === 'DINNER' ? '19:30:00' : '12:00:00');
        const ends = mealSlot === 'BREAKFAST' ? '10:00:00' : (mealSlot === 'DINNER' ? '22:30:00' : '15:30:00');
        await db.from('meal_slots').insert({
          provider_id: providerId,
          name: mealSlot.toLowerCase(),
          starts_at_local: starts,
          ends_at_local: ends,
          active: true,
        });
      }
    }

    const token = generateCounterQRToken({ providerId, date, slot: mealSlot });
    return NextResponse.json({
      success: true,
      token,
      provider_id: providerId,
      date,
      slot: mealSlot,
    }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    const token = generateCounterQRToken({ providerId, date, slot: mealSlot });
    return NextResponse.json({
      success: true,
      token,
      provider_id: providerId,
      date,
      slot: mealSlot,
    }, { headers: { 'Cache-Control': 'private, no-store' } });
  }
}
