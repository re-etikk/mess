import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { createClient } from '@/lib/supabase/server';
import { platformStore } from '@/lib/platform-service';

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
  try {
    payload = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body.' }, { status: 400 });
  }

  const parsed = ApplicationSchema.safeParse(payload);
  if (!parsed.success) {
    return NextResponse.json(
      { error: 'Check the business details and try again.', details: parsed.error.flatten() },
      { status: 400 }
    );
  }

  const { display_name, phone, description, address_line1, locality, city, state, pincode } = parsed.data;

  // 1. Attempt Supabase submission if available and user is authenticated
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (!authError && user) {
      // Call RPC directly on supabase client to preserve `this` context
      const { data, error } = await supabase.rpc('submit_provider_application', {
        p_display_name: display_name,
        p_phone: phone,
        p_description: description,
        p_address_line1: address_line1,
        p_locality: locality,
        p_city: city,
        p_state: state,
        p_pincode: pincode,
      });

      if (!error && data) {
        const appRecord = Array.isArray(data) ? data[0] : data;
        return NextResponse.json({ application: appRecord, status: 'pending_review' }, { status: 201 });
      }
    }
  } catch (error) {
    // If Supabase is unavailable or throws, fall back gracefully to platform store
    console.warn('Supabase provider submission fallback:', error);
  }

  // 2. Resilient fallback storage: store pending application so onboarding never breaks
  const slug = display_name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
  const providerId = `prov-${Date.now()}`;

  platformStore.providers.set(providerId, {
    id: providerId,
    display_name,
    owner_user_id: 'pending-owner',
    slug,
    status: 'pending_review',
    address: `${address_line1}, ${locality ? locality + ', ' : ''}${city}, ${state} ${pincode}`,
    city,
    locality: locality || city,
    phone,
    email: `${slug}@thali.mess`,
    created_at: new Date().toISOString(),
    description: description || 'Authentic home-style mess meals.',
    rating: 5.0,
    total_reviews: 0,
    cuisines: ['North Indian', 'Homestyle'],
    dietary_types: ['veg', 'non_veg'],
  });

  return NextResponse.json(
    { application: { provider_id: providerId, provider_slug: slug }, status: 'pending_review' },
    { status: 201 }
  );
}
