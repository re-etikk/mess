import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { getCurrentMealSlot } from '@/lib/platform-service';
import { generateCounterQRToken, getIndiaDateString } from '@/lib/crypto';

export async function issueProviderQr(req: NextRequest, providerId: string | null, slot: string | null) {
  if (!providerId) return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  const mealSlot = (slot || getCurrentMealSlot() || 'LUNCH').toUpperCase();
  if (mealSlot.length > 40) return NextResponse.json({ success: false, error: 'Invalid meal slot.' }, { status: 400 });

  const date = getIndiaDateString();
  const token = generateCounterQRToken({ providerId, date, slot: mealSlot });

  const db = getAdminClient();
  if (db) {
    try {
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
    } catch {}
  }

  return NextResponse.json({
    success: true,
    token,
    provider_id: providerId,
    date,
    slot: mealSlot,
  }, { headers: { 'Cache-Control': 'private, no-store' } });
}
