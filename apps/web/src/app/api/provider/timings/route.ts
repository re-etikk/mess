import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getAdminClient } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { ensurePlanSlotsLinked } from '@/lib/auth-session';
import { isUndefinedColumnError } from '@/lib/kitchen-status';

export const dynamic = 'force-dynamic';
export const fetchCache = 'force-no-store';

function displayClock(value: string) {
  const [hourText, minuteText] = value.split(':');
  const hour = Number(hourText);
  const suffix = hour >= 12 ? 'PM' : 'AM';
  const hour12 = hour % 12 || 12;
  return `${String(hour12).padStart(2, '0')}:${minuteText} ${suffix}`;
}

function normalizeClock(value: string): string | null {
  const match = value.trim().match(/^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$/i);
  if (!match) return null;
  let hour = Number(match[1]);
  const minute = Number(match[2]);
  const meridiem = match[3]?.toUpperCase();
  if (minute > 59 || (meridiem && (hour < 1 || hour > 12)) || hour > 23) return null;
  if (meridiem === 'AM') hour = hour === 12 ? 0 : hour;
  if (meridiem === 'PM') hour = hour === 12 ? 12 : hour + 12;
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00`;
}

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id') || params.get('providerId') || '';
  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  const db = access.ok ? getAdminClient() : null;

  try {
    const client = db || (await createClient());
    const [slotsPrimary, hoursResult] = await Promise.all([
      client
        .from('meal_slots')
        .select('id,name,starts_at_local,ends_at_local,active,daily_capacity,single_meal_price_paise')
        .eq('provider_id', providerId)
        .order('starts_at_local'),
      client
        .from('provider_operating_hours')
        .select('weekday,opens_at,closes_at,closed')
        .eq('provider_id', providerId)
        .order('weekday'),
    ]);

    let slotsData: any[] | null = slotsPrimary.data as any[] | null;
    let slotsErr = slotsPrimary.error;
    if (isUndefinedColumnError(slotsErr, 'single_meal_price_paise')) {
      const slotsFb = await client
        .from('meal_slots')
        .select('id,name,starts_at_local,ends_at_local,active,daily_capacity')
        .eq('provider_id', providerId)
        .order('starts_at_local');
      slotsData = slotsFb.data as any[] | null;
      slotsErr = slotsFb.error;
    }

    if (slotsErr) throw slotsErr;

    const cleanSlots = (slotsData ?? []).filter((s) => String(s.name || '').trim().toLowerCase() !== 'all');
    const timings = Object.fromEntries(cleanSlots.map((slot) => [slot.name.toLowerCase(), {
      enabled: slot.active,
      start: displayClock(slot.starts_at_local),
      end: displayClock(slot.ends_at_local),
      single_meal_price_paise: slot.single_meal_price_paise ?? null,
      single_meal_price_inr:
        slot.single_meal_price_paise != null && Number(slot.single_meal_price_paise) > 0
          ? Math.round(Number(slot.single_meal_price_paise) / 100)
          : null,
    }]));

    return NextResponse.json(
      {
        success: true,
        slots: cleanSlots,
        operating_hours: hoursResult.data ?? [],
        timings,
      },
      { headers: { 'Cache-Control': 'private, no-store' } }
    );
  } catch (error) {
    console.error('Provider timings GET failed:', error instanceof Error ? error.message : 'unknown');
    return NextResponse.json(
      { success: false, error: 'Operating hours could not be loaded.' },
      { status: 503 }
    );
  }
}

const UpdateTimingsSchema = z.object({
  provider_id: z.string().uuid(),
  supports_delivery: z.boolean().optional(),
  supports_pickup: z.boolean().optional(),
  slots: z
    .array(
      z.object({
        id: z.string().uuid().optional(),
        name: z.string().trim().min(1).max(40),
        starts_at_local: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/),
        ends_at_local: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/),
        active: z.boolean().default(true),
        daily_capacity: z.number().int().positive().optional(),
        single_meal_price_inr: z.number().nonnegative().max(10000).nullable().optional(),
        single_meal_price_paise: z.number().int().nonnegative().max(1_000_000).nullable().optional(),
      })
    )
    .optional(),
  operating_hours: z
    .array(
      z.object({
        weekday: z.number().int().min(0).max(6),
        opens_at: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/).nullable().optional(),
        closes_at: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/).nullable().optional(),
        closed: z.boolean().default(false),
      })
    )
    .optional(),
  replace_slots: z.boolean().optional(),
});

export async function POST(req: NextRequest) {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid request body.' }, { status: 400 });
  }

  let normalizedBody = body;
  if (body && typeof body === 'object' && !Array.isArray(body) && !('slots' in body)) {
    const legacy = body as Record<string, unknown>;
    const meals = ['breakfast', 'lunch', 'snacks', 'dinner'];
    if (meals.some((meal) => meal in legacy)) {
      const slots = meals.flatMap((meal) => {
        const value = legacy[meal];
        if (!value || typeof value !== 'object') return [];
        const timing = value as { enabled?: unknown; start?: unknown; end?: unknown; single_meal_price_inr?: unknown; single_meal_price_paise?: unknown };
        const isEnabled = timing.enabled !== false;
        const start = typeof timing.start === 'string' ? normalizeClock(timing.start) : null;
        const end = typeof timing.end === 'string' ? normalizeClock(timing.end) : null;
        const fallbackStart =
          meal === 'breakfast' ? '07:30:00' : meal === 'snacks' ? '16:30:00' : meal === 'dinner' ? '19:30:00' : '12:00:00';
        const fallbackEnd =
          meal === 'breakfast' ? '10:00:00' : meal === 'snacks' ? '18:30:00' : meal === 'dinner' ? '22:30:00' : '15:30:00';
        const priceInr = typeof timing.single_meal_price_inr === 'number' ? timing.single_meal_price_inr : undefined;
        const pricePaise = typeof timing.single_meal_price_paise === 'number' ? timing.single_meal_price_paise : undefined;
        return [{
          name: meal,
          starts_at_local: start || fallbackStart,
          ends_at_local: end || fallbackEnd,
          active: isEnabled,
          ...(priceInr !== undefined ? { single_meal_price_inr: priceInr } : {}),
          ...(pricePaise !== undefined ? { single_meal_price_paise: pricePaise } : {}),
        }];
      });
      normalizedBody = {
        provider_id: legacy.provider_id,
        supports_delivery: legacy.supports_delivery,
        supports_pickup: legacy.supports_pickup,
        slots,
        replace_slots: false,
      };
    }
  }

  const parsed = UpdateTimingsSchema.safeParse(normalizedBody);
  if (!parsed.success) {
    return NextResponse.json(
      { success: false, error: 'Please use valid time format like 08:00 AM - 10:00 AM.', details: parsed.error.flatten() },
      { status: 400 }
    );
  }

  const input = parsed.data;
  const access = await requireProviderOwnership(req, input.provider_id);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  let db = getAdminClient();
  if (!db) {
    try {
      db = await createClient();
    } catch {}
  }
  if (!db) {
    return NextResponse.json({ success: false, error: 'Database credentials are missing on the server.' }, { status: 503 });
  }

  try {
    if (input.supports_delivery !== undefined || input.supports_pickup !== undefined) {
      await db
        .from('providers')
        .update({
          ...(input.supports_delivery !== undefined ? { supports_delivery: input.supports_delivery } : {}),
          ...(input.supports_pickup !== undefined ? { supports_pickup: input.supports_pickup } : {}),
          updated_at: new Date().toISOString(),
        })
        .eq('id', input.provider_id);
    }
    // 1. Update/Upsert meal slots if provided
    if (input.slots && input.slots.length > 0) {
      for (const slot of input.slots) {
        if (slot.name.trim().toLowerCase() === 'all') continue;
        const hasExplicitRate = slot.single_meal_price_paise !== undefined || slot.single_meal_price_inr !== undefined;
        const computedRatePaise =
          slot.single_meal_price_paise !== undefined
            ? slot.single_meal_price_paise && slot.single_meal_price_paise > 0 ? slot.single_meal_price_paise : null
            : slot.single_meal_price_inr !== undefined
              ? slot.single_meal_price_inr && slot.single_meal_price_inr > 0 ? Math.round(slot.single_meal_price_inr * 100) : null
              : undefined;

        const baseValues = {
          name: slot.name,
          starts_at_local: slot.starts_at_local,
          ends_at_local: slot.ends_at_local,
          active: slot.active,
          daily_capacity: slot.daily_capacity || null,
          updated_at: new Date().toISOString(),
        };
        const valuesWithRate = hasExplicitRate ? { ...baseValues, single_meal_price_paise: computedRatePaise ?? null } : baseValues;

        if (slot.id) {
          let { error } = await db.from('meal_slots').update(valuesWithRate).eq('id', slot.id).eq('provider_id', input.provider_id);
          if (hasExplicitRate && isUndefinedColumnError(error, 'single_meal_price_paise')) {
            const fb = await db.from('meal_slots').update(baseValues).eq('id', slot.id).eq('provider_id', input.provider_id);
            error = fb.error;
          }
          if (error) throw error;
        } else {
          const { data: existing, error: lookupError } = await db.from('meal_slots')
            .select('id').eq('provider_id', input.provider_id).ilike('name', slot.name).limit(1).maybeSingle();
          if (lookupError) throw lookupError;
          let { error } = existing
            ? await db.from('meal_slots').update(valuesWithRate).eq('id', existing.id).eq('provider_id', input.provider_id)
            : await db.from('meal_slots').insert({ ...valuesWithRate, provider_id: input.provider_id });
          if (hasExplicitRate && isUndefinedColumnError(error, 'single_meal_price_paise')) {
            const fb = existing
              ? await db.from('meal_slots').update(baseValues).eq('id', existing.id).eq('provider_id', input.provider_id)
              : await db.from('meal_slots').insert({ ...baseValues, provider_id: input.provider_id });
            error = fb.error;
          }
          if (error) throw error;
        }
      }
    }
    if (input.replace_slots) {
      const activeNames = (input.slots ?? []).map((slot) => slot.name.toLowerCase());
      const { data: existingSlots, error: existingError } = await db.from('meal_slots').select('id,name').eq('provider_id', input.provider_id);
      if (existingError) throw existingError;
      for (const existing of existingSlots ?? []) {
        if (!activeNames.includes(existing.name.toLowerCase())) {
          const { error } = await db.from('meal_slots').update({ active: false, updated_at: new Date().toISOString() }).eq('id', existing.id).eq('provider_id', input.provider_id);
          if (error) throw error;
        }
      }
    }

    // 2. Upsert operating hours if provided
    if (input.operating_hours && input.operating_hours.length > 0) {
      for (const h of input.operating_hours) {
        await db.from('provider_operating_hours').upsert(
          {
            provider_id: input.provider_id,
            weekday: h.weekday,
            opens_at: h.opens_at || null,
            closes_at: h.closes_at || null,
            closed: h.closed,
            updated_at: new Date().toISOString(),
          },
          { onConflict: 'provider_id,weekday' }
        );
      }
    }

    const adminClient = getAdminClient();
    if (adminClient) {
      await ensurePlanSlotsLinked(adminClient, input.provider_id);
    }

    return NextResponse.json({ success: true, message: 'Operating timings persisted successfully.' });
  } catch (error) {
    console.error('Provider timings update failed:', error instanceof Error ? error.message : 'unknown');
    return NextResponse.json({ success: false, error: 'Failed to persist operating timings.' }, { status: 503 });
  }
}
