import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { createClient } from '@/lib/supabase/server';

const ApplicationSchema = z.object({
  display_name: z.string().trim().min(2).max(120),
  phone: z.string().trim().regex(/^\+?[0-9 ()-]{7,20}$/),
  description: z.string().trim().max(1000).default(''),
  address_line1: z.string().trim().min(3).max(200),
  locality: z.string().trim().max(120).default(''),
  city: z.string().trim().min(2).max(100),
  state: z.string().trim().min(2).max(100),
  pincode: z.string().trim().regex(/^[0-9]{6}$/),
});

export async function POST(request: NextRequest) {
  let payload: unknown;
  try { payload = await request.json(); } catch { return NextResponse.json({ error: 'Invalid JSON body.' }, { status: 400 }); }
  const parsed = ApplicationSchema.safeParse(payload);
  if (!parsed.success) return NextResponse.json({ error: 'Check the business details and try again.', details: parsed.error.flatten() }, { status: 400 });

  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return NextResponse.json({ error: 'Sign in before submitting a provider application.' }, { status: 401 });
    const rpc = supabase.rpc as unknown as (name: string, args: Record<string, string>) => Promise<{ data: Array<{ provider_id: string; provider_slug: string }> | null; error: { message: string } | null }>;
    const { data, error } = await rpc('submit_provider_application', {
      p_display_name: parsed.data.display_name,
      p_phone: parsed.data.phone,
      p_description: parsed.data.description,
      p_address_line1: parsed.data.address_line1,
      p_locality: parsed.data.locality,
      p_city: parsed.data.city,
      p_state: parsed.data.state,
      p_pincode: parsed.data.pincode,
    });
    if (error) return NextResponse.json({ error: 'Application could not be saved. Confirm the reviewed database migration is applied.' }, { status: 503 });
    return NextResponse.json({ application: data?.[0], status: 'pending_review' }, { status: 201 });
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : 'Provider application is unavailable.' }, { status: 503 });
  }
}
