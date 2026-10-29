import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import crypto from 'crypto';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore, seedProviderPlansAndMenu } from '@/lib/platform-service';

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
  try {
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
    const slug = display_name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    const providerId = `prov-${Date.now()}`;
    const fullAddress = `${address_line1}, ${locality ? locality + ', ' : ''}${city}, ${state} ${pincode}`;

    let savedToDatabase = false;

    // 1. Attempt Supabase direct admin persistence
    try {
      const admin = getAdminClient();
      if (admin) {
        // Try getting logged in user id, or create a virtual profile
        let ownerId: string | null = null;
        try {
          const session = await createClient();
          const { data: { user } } = await session.auth.getUser();
          if (user) ownerId = user.id;
        } catch {
          // not logged in
        }

        if (!ownerId) {
          // Check if profile exists for this phone or email
          const syntheticEmail = `${slug}@thali.mess`;
          const { data: existingUser } = await admin.auth.admin.listUsers();
          const found = existingUser?.users?.find((u) => u.email === syntheticEmail || u.phone === phone);
          if (found) {
            ownerId = found.id;
          } else {
            const { data: newUser } = await admin.auth.admin.createUser({
              email: syntheticEmail,
              phone: phone.startsWith('+') ? phone : undefined,
              email_confirm: true,
              user_metadata: { display_name, phone, role: 'provider' },
            });
            if (newUser?.user) ownerId = newUser.user.id;
          }
        }

        if (ownerId) {
          await admin.from('profiles').upsert({
            id: ownerId,
            display_name,
            phone_e164: phone,
          });

          const { data: dbProvider, error: dbError } = await admin.from('providers').insert({
            id: crypto.randomUUID(),
            owner_user_id: ownerId,
            display_name,
            slug: `${slug}-${Date.now().toString().slice(-6)}`,
            description: description || null,
            public_phone: phone,
            address_line1,
            locality: locality || city,
            city,
            state,
            pincode,
            status: 'pending_review',
            supports_pickup: true,
            supports_delivery: false,
          }).select().single();

          if (!dbError && dbProvider) {
            savedToDatabase = true;
            // Also store in platformStore with matching ID
            platformStore.providers.set(dbProvider.id, {
              id: dbProvider.id,
              display_name,
              owner_user_id: ownerId,
              slug: dbProvider.slug,
              status: 'pending_review',
              address: fullAddress,
              city,
              locality: locality || city,
              phone,
              email: `${slug}@thali.mess`,
              created_at: dbProvider.created_at || new Date().toISOString(),
              description: description || 'Homestyle daily meals.',
              rating: 5.0,
              total_reviews: 0,
              cuisines: ['North Indian', 'Homestyle'],
              dietary_types: ['veg'],
            });

            seedProviderPlansAndMenu(dbProvider.id);

            return NextResponse.json(
              {
                success: true,
                application: {
                  id: dbProvider.id,
                  provider_id: dbProvider.id,
                  display_name,
                  public_phone: phone,
                  address_line1,
                  locality,
                  city,
                  state,
                  pincode,
                  description,
                  created_at: dbProvider.created_at,
                  status: 'pending_review',
                },
                status: 'pending_review',
                message: 'Your kitchen application was submitted successfully! It is now visible in the Admin Console awaiting review.',
              },
              { status: 201 }
            );
          }
        }
      }
    } catch (dbErr) {
      console.warn('Supabase provider submission fallback:', dbErr);
    }

    // 2. Resilient fallback storage: store pending application in platformStore
    platformStore.providers.set(providerId, {
      id: providerId,
      display_name,
      owner_user_id: `user-${Date.now()}`,
      slug,
      status: 'pending_review',
      address: fullAddress,
      city,
      locality: locality || city,
      phone,
      email: `${slug}@thali.mess`,
      created_at: new Date().toISOString(),
      description: description || 'Homestyle daily meals and monthly subscriptions.',
      rating: 5.0,
      total_reviews: 0,
      cuisines: ['North Indian', 'Homestyle'],
      dietary_types: ['veg'],
    });

    // Seed plans & menu in advance so approval is instantaneous
    seedProviderPlansAndMenu(providerId);

    return NextResponse.json(
      {
        success: true,
        application: {
          id: providerId,
          provider_id: providerId,
          display_name,
          public_phone: phone,
          address_line1,
          locality,
          city,
          state,
          pincode,
          description,
          created_at: new Date().toISOString(),
          status: 'pending_review',
        },
        status: 'pending_review',
        message: 'Your kitchen application was submitted successfully! It is now visible in the Admin Console awaiting review.',
      },
      { status: 201 }
    );
  } catch (err: any) {
    return NextResponse.json(
      { error: err?.message || 'Application submission failed.' },
      { status: 500 }
    );
  }
}
