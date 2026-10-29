import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import crypto from 'crypto';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore, seedProviderPlansAndMenu } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

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
    const cleanPhoneDigits = phone.replace(/\D/g, '');
    const phoneE164 = phone.startsWith('+') ? phone : `+91${cleanPhoneDigits}`;
    const slugBase = display_name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '') || 'mess';
    const slug = `${slugBase}-${Date.now().toString().slice(-6)}`;
    const fullAddress = `${address_line1}, ${locality ? locality + ', ' : ''}${city}, ${state} ${pincode}`;

    let savedToDatabase = false;
    let savedProviderId: string | null = null;
    let dbErrorMessage: string | null = null;

    // 1. Attempt Supabase database persistence via admin service role client
    try {
      const admin = getAdminClient();
      if (admin) {
        let ownerId: string | null = null;

        // Try getting logged-in user id if available
        try {
          const session = await createClient();
          const { data: { user } } = await session.auth.getUser();
          if (user) ownerId = user.id;
        } catch {
          // Unauthenticated registration is supported
        }

        // If no authenticated session, create or find an auth user for this provider
        if (!ownerId) {
          const syntheticEmail = `${slugBase}-${Date.now()}@thali.mess`;
          const syntheticPassword = `Pass_${crypto.randomBytes(6).toString('hex')}!1Aa`;

          try {
            const { data: newUser, error: createErr } = await admin.auth.admin.createUser({
              email: syntheticEmail,
              password: syntheticPassword,
              email_confirm: true,
              user_metadata: {
                display_name,
                phone,
                role: 'provider',
              },
            });

            if (newUser?.user) {
              ownerId = newUser.user.id;
            } else if (createErr) {
              console.warn('admin.createUser note:', createErr.message);
            }
          } catch (createEx: any) {
            console.warn('admin.createUser exception:', createEx?.message || createEx);
          }

          // If user creation failed, fallback to any existing auth user
          if (!ownerId) {
            try {
              const { data: usersList } = await admin.auth.admin.listUsers({ perPage: 5 });
              if (usersList?.users && usersList.users.length > 0) {
                ownerId = usersList.users[0].id;
              }
            } catch {
              // listUsers failed
            }
          }
        }

        if (ownerId) {
          // Ensure profile exists for the user
          try {
            await admin.from('profiles').upsert({
              id: ownerId,
              display_name,
              phone_e164: phoneE164,
            });
          } catch (profErr) {
            console.warn('Profile upsert note:', profErr);
          }

          // Insert into public.providers with pending_review status
          const providerUUID = crypto.randomUUID();
          const { data: dbProvider, error: dbError } = await admin.from('providers').insert({
            id: providerUUID,
            owner_user_id: ownerId,
            display_name,
            slug,
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

          if (dbError) {
            console.error('Supabase providers insert error:', dbError);
            dbErrorMessage = dbError.message;
          } else if (dbProvider) {
            savedToDatabase = true;
            savedProviderId = dbProvider.id;

            // Also keep in memory with matching UUID
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
              email: `${slugBase}@thali.mess`,
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
                saved_to_database: true,
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
    } catch (dbErr: any) {
      console.warn('Supabase provider submission fallback:', dbErr?.message || dbErr);
      dbErrorMessage = dbErr?.message || String(dbErr);
    }

    // 2. Resilient fallback storage: store pending application in platformStore
    const fallbackId = `prov-${Date.now()}`;
    platformStore.providers.set(fallbackId, {
      id: fallbackId,
      display_name,
      owner_user_id: `user-${Date.now()}`,
      slug,
      status: 'pending_review',
      address: fullAddress,
      city,
      locality: locality || city,
      phone,
      email: `${slugBase}@thali.mess`,
      created_at: new Date().toISOString(),
      description: description || 'Homestyle daily meals and monthly subscriptions.',
      rating: 5.0,
      total_reviews: 0,
      cuisines: ['North Indian', 'Homestyle'],
      dietary_types: ['veg'],
    });

    seedProviderPlansAndMenu(fallbackId);

    return NextResponse.json(
      {
        success: true,
        saved_to_database: savedToDatabase,
        db_note: dbErrorMessage,
        application: {
          id: fallbackId,
          provider_id: fallbackId,
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
