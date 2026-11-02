import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getAdminClient } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

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
    const [slotsResult, hoursResult] = await Promise.all([
      client
        .from('meal_slots')
        .select('id,name,starts_at_local,ends_at_local,active,daily_capacity')
        .eq('provider_id', providerId)
        .order('starts_at_local'),
      client
        .from('provider_operating_hours')
        .select('weekday,opens_at,closes_at,closed')
        .eq('provider_id', providerId)
        .order('weekday'),
    ]);

    if (slotsResult.error) throw slotsResult.error;

    const timings = Object.fromEntries((slotsResult.data ?? []).map((slot) => [slot.name.toLowerCase(), {
      enabled: slot.active,
      start: displayClock(slot.starts_at_local),
      end: displayClock(slot.ends_at_local),
    }]));

    return NextResponse.json(
      {
        success: true,
        slots: slotsResult.data ?? [],
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
  slots: z
    .array(
      z.object({
        id: z.string().uuid().optional(),
        name: z.string().trim().min(1).max(40),
        starts_at_local: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/),
        ends_at_local: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/),
        active: z.boolean().default(true),
        daily_capacity: z.number().int().positive().optional(),
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
    return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 });
  }

  let normalizedBody = body;
  if (body && typeof body === 'object' && !Array.isArray(body) && !('slots' in body)) {
    const legacy = body as Record<string, unknown>;
    const meals = ['breakfast', 'lunch', 'dinner'];
    if (meals.some((meal) => meal in legacy)) {
      const slots = meals.flatMap((meal) => {
        const value = legacy[meal];
        if (!value || typeof value !== 'object') return [];
        const timing = value as { enabled?: unknown; start?: unknown; end?: unknown };
        if (timing.enabled === false) return [];
        if (typeof timing.start !== 'string' || typeof timing.end !== 'string') return [];
        const start = normalizeClock(timing.start);
        const end = normalizeClock(timing.end);
        if (!start || !end || start === end) return [];
        return [{ name: meal, starts_at_local: start, ends_at_local: end, active: true }];
      });
      normalizedBody = { provider_id: legacy.provider_id, slots, replace_slots: true };
    }
  }

  const parsed = UpdateTimingsSchema.safeParse(normalizedBody);
  if (!parsed.success) {
    return NextResponse.json(
      { success: false, error: 'Invalid timing payload.', details: parsed.error.flatten() },
      { status: 400 }
    );
  }

  const input = parsed.data;
  const access = await requireProviderOwnership(req, input.provider_id);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const db = getAdminClient();
  if (!db) {
    return NextResponse.json({ success: false, error: 'Timings service is not configured.' }, { status: 503 });
  }

  try {
    // 1. Update/Upsert meal slots if provided
    if (input.slots && input.slots.length > 0) {
      for (const slot of input.slots) {
        if (slot.id) {
          const { error } = await db
            .from('meal_slots')
            .update({
              name: slot.name,
              starts_at_local: slot.starts_at_local,
              ends_at_local: slot.ends_at_local,
              active: slot.active,
              daily_capacity: slot.daily_capacity || null,
              updated_at: new Date().toISOString(),
            })
            .eq('id', slot.id)
            .eq('provider_id', input.provider_id);
          if (error) throw error;
        } else {
          const { data: existing, error: lookupError } = await db.from('meal_slots')
            .select('id').eq('provider_id', input.provider_id).ilike('name', slot.name).limit(1).maybeSingle();
          if (lookupError) throw lookupError;
          const values = {
            name: slot.name,
            starts_at_local: slot.starts_at_local,
            ends_at_local: slot.ends_at_local,
            active: slot.active,
            daily_capacity: slot.daily_capacity || null,
            updated_at: new Date().toISOString(),
          };
          const { error } = existing
            ? await db.from('meal_slots').update(values).eq('id', existing.id).eq('provider_id', input.provider_id)
            : await db.from('meal_slots').insert({ ...values, provider_id: input.provider_id });
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

    return NextResponse.json({ success: true, message: 'Operating timings persisted successfully.' });
  } catch (error) {
    console.error('Provider timings update failed:', error instanceof Error ? error.message : 'unknown');
    return NextResponse.json({ success: false, error: 'Failed to persist operating timings.' }, { status: 503 });
  }
}
