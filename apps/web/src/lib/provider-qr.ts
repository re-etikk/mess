import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { getCurrentMealSlot } from '@/lib/platform-service';
import { generateCounterQRToken, getIndiaDateString } from '@/lib/crypto';
import { requireProviderOwnership } from '@/lib/provider-auth';

export async function issueProviderQr(req: NextRequest, providerId: string | null, slot: string | null) {
  if (!providerId) return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  const mealSlot = slot || getCurrentMealSlot();
  if (mealSlot.length > 40) return NextResponse.json({ success: false, error: 'Invalid meal slot.' }, { status: 400 });

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  try {
    const db = getAdminClient();
    if (!db) throw new Error('QR generation requires server-side Supabase configuration.');
    const [{ data: provider, error }, { data: slots, error: slotError }] = await Promise.all([
      db.from('providers').select('id,status').eq('id', providerId).maybeSingle(),
      db.from('meal_slots').select('id,name').eq('provider_id', providerId).eq('active', true).ilike('name', mealSlot).limit(1),
    ]);
    if (error || slotError) throw error || slotError;
    if (!provider || provider.status !== 'active') {
      return NextResponse.json({ success: false, error: 'A QR code is available only after the provider is approved and active.' }, { status: 403 });
    }
    if (!slots?.length) return NextResponse.json({ success: false, error: 'This meal slot is not configured for the provider.' }, { status: 404 });
    const date = getIndiaDateString();
    const token = generateCounterQRToken({ providerId, date, slot: mealSlot });
    return NextResponse.json({ success: true, token, provider_id: providerId, date, slot: mealSlot }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'QR generation is unavailable.';
    return NextResponse.json({ success: false, error: message }, { status: 503 });
  }
}
