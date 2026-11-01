import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getAdminClient } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

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

    return NextResponse.json(
      {
        success: true,
        slots: slotsResult.data ?? [],
        operating_hours: hoursResult.data ?? [],
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
});

export async function POST(req: NextRequest) {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 });
  }

  const parsed = UpdateTimingsSchema.safeParse(body);
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
          await db
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
        } else {
          await db.from('meal_slots').insert({
            provider_id: input.provider_id,
            name: slot.name,
            starts_at_local: slot.starts_at_local,
            ends_at_local: slot.ends_at_local,
            active: slot.active,
            daily_capacity: slot.daily_capacity || null,
          });
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
