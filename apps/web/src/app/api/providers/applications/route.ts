import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

const ApplicationSchema = z.object({
  display_name: z.string().trim().min(2).max(120),
  phone: z.string().trim().regex(/^\+?[0-9 ()-]{7,20}$/),
  description: z.string().trim().max(1000).optional().default(''),
  address_line1: z.string().trim().min(3).max(200),
  locality: z.string().trim().max(120).optional().default(''),
  city: z.string().trim().min(2).max(100),
  state: z.string().trim().min(2).max(100),
  pincode: z.string().trim().regex(/^[0-9]{6}$/),
});

export async function POST(req: NextRequest) {
  let payload: unknown;
  try { payload = await req.json(); } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 });
  }
  const parsed = ApplicationSchema.safeParse(payload);
  if (!parsed.success) {
    return NextResponse.json({ success: false, error: 'Check the business details and try again.', details: parsed.error.flatten() }, { status: 400 });
  }

  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return NextResponse.json({ success: false, error: 'Sign in before submitting a partner application.' }, { status: 401 });

    const form = parsed.data;
    const { data, error } = await supabase.rpc('submit_provider_application', {
      p_display_name: form.display_name,
      p_phone: form.phone,
      p_description: form.description,
      p_address_line1: form.address_line1,
      p_locality: form.locality,
      p_city: form.city,
      p_state: form.state,
      p_pincode: form.pincode,
    });
    if (error) {
      const duplicate = /already awaiting review/i.test(error.message);
      return NextResponse.json({ success: false, error: error.message }, { status: duplicate ? 409 : 400 });
    }
    const application = Array.isArray(data) ? data[0] : data;
    if (!application?.provider_id) {
      return NextResponse.json({ success: false, error: 'The application was not persisted.' }, { status: 503 });
    }
    return NextResponse.json({
      success: true,
      saved_to_database: true,
      user: { id: user.id, email: user.email },
      application: { id: application.provider_id, provider_id: application.provider_id, slug: application.provider_slug, display_name: form.display_name, status: 'pending_review' },
      status: 'pending_review',
      message: 'Your application was submitted for review.',
    }, { status: 201 });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Partner application is unavailable.';
    return NextResponse.json({ success: false, error: message }, { status: 503 });
  }
}
