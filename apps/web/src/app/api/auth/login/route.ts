import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';
import { getAdminClient } from '@/lib/supabase/admin';
import { createClient as createSessionClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const rawIdentifier = (body.email || body.phone || '').trim();
    const password = body.password;
    const requestedRole = body.role?.trim().toLowerCase();

    if (!rawIdentifier || !password) {
      return NextResponse.json(
        { success: false, error: 'Email/phone and password are required.' },
        { status: 400 }
      );
    }

    const email = rawIdentifier.toLowerCase();
    const cleanDigits = rawIdentifier.replace(/\D/g, '');

    let authenticatedUserId: string | null = null;
    let authenticatedEmail: string = email;
    let resolvedRole: string = requestedRole || 'customer';
    let providerData: any = null;

    // 1. Attempt Supabase Auth Password Verification
    let supabaseAuthSucceeded = false;
    try {
      const sessionClient = await createSessionClient();
      const { data: authData, error: authError } = await sessionClient.auth.signInWithPassword({
        email,
        password,
      });

      if (!authError && authData.user) {
        supabaseAuthSucceeded = true;
        authenticatedUserId = authData.user.id;
        authenticatedEmail = authData.user.email || email;

        // Check if user has explicit admin role
        const { data: roleRow } = await sessionClient
          .from('user_roles')
          .select('role')
          .eq('user_id', authData.user.id)
          .is('revoked_at', null)
          .maybeSingle();

        if (roleRow?.role === 'admin' || authenticatedEmail === 'ritik45chaurasia@gmail.com') {
          resolvedRole = 'admin';
        } else if (authData.user.user_metadata?.role === 'provider' || requestedRole === 'provider') {
          resolvedRole = 'provider';
        } else {
          resolvedRole = 'customer';
        }
      }
    } catch {
      // Supabase unconfigured or offline fallback
    }

    // 2. If Supabase Auth failed or unconfigured, check Supabase Admin / user metadata credentials
    if (!supabaseAuthSucceeded) {
      const admin = getAdminClient();
      let matchedUser: any = null;

      if (admin) {
        try {
          const { data: usersData } = await admin.auth.admin.listUsers({ perPage: 100 });
          if (usersData?.users) {
            matchedUser = usersData.users.find((u) => {
              const meta = u.user_metadata || {};
              const uPhoneDigits = (meta.phone || '').replace(/\D/g, '');
              const matchesIdentifier =
                u.id === rawIdentifier ||
                u.email?.toLowerCase() === email ||
                (cleanDigits.length >= 7 && uPhoneDigits.includes(cleanDigits)) ||
                meta.application?.id === rawIdentifier;

              return matchesIdentifier;
            });

            if (matchedUser) {
              const meta = matchedUser.user_metadata || {};
              // Verify password against stored password or initial password
              const expectedPassword = meta.initial_password || meta.login_password || meta.password;
              if (expectedPassword && expectedPassword === password) {
                supabaseAuthSucceeded = true;
                authenticatedUserId = matchedUser.id;
                authenticatedEmail = matchedUser.email || email;
                resolvedRole = (meta.role === 'admin' || authenticatedEmail === 'ritik45chaurasia@gmail.com')
                  ? 'admin'
                  : (meta.role === 'provider' || requestedRole === 'provider' ? 'provider' : 'customer');
              }
            }
          }
        } catch {}
      }
    }

    // 3. Fallback verification for demo / offline platformStore accounts
    if (!supabaseAuthSucceeded) {
      // Only recognize hardcoded platform accounts if password matches
      if (email === 'ritik45chaurasia@gmail.com' && (password === 'admin123' || password === 'admin@123' || password === 'Ritik@2026')) {
        authenticatedUserId = 'usr-admin-ritik';
        resolvedRole = 'admin';
        supabaseAuthSucceeded = true;
      } else if (email === 'owner@radhemess.in' && (password === 'owner123' || password === 'mess123')) {
        authenticatedUserId = 'prov-radhe-001';
        resolvedRole = 'provider';
        supabaseAuthSucceeded = true;
      } else {
        // Check if there is an in-memory provider registered with matching password
        const inMemProvider = Array.from(platformStore.providers.values()).find(
          (p: any) => (p.email?.toLowerCase() === email || p.id === rawIdentifier) && p.password === password
        );
        if (inMemProvider) {
          authenticatedUserId = inMemProvider.id;
          resolvedRole = 'provider';
          providerData = inMemProvider;
          supabaseAuthSucceeded = true;
        }
      }
    }

    // If all credential verifications failed, reject with 401 Unauthorized
    if (!supabaseAuthSucceeded) {
      return NextResponse.json(
        { success: false, error: 'Invalid email/phone or password. Please verify your credentials.' },
        { status: 401 }
      );
    }

    // 4. If Provider role, resolve associated Kitchen entity
    if (resolvedRole === 'provider') {
      // Check in platformStore
      let found = Array.from(platformStore.providers.values()).find(
        (p) =>
          p.email.toLowerCase() === authenticatedEmail ||
          p.id === authenticatedUserId ||
          p.owner_user_id === authenticatedUserId ||
          (cleanDigits.length >= 7 && p.phone.replace(/\D/g, '').includes(cleanDigits))
      );

      // Check in Supabase DB if not in platformStore
      if (!found) {
        try {
          const admin = getAdminClient();
          if (admin) {
            const { data: dbMatches } = await admin
              .from('providers')
              .select('*')
              .or(`owner_user_id.eq.${authenticatedUserId},id.eq.${authenticatedUserId},public_email.ilike.%${authenticatedEmail}%`)
              .limit(1);

            if (dbMatches && dbMatches.length > 0) {
              const dbP = dbMatches[0];
              found = {
                id: dbP.id,
                owner_user_id: dbP.owner_user_id || authenticatedUserId,
                display_name: dbP.display_name,
                slug: dbP.slug,
                description: dbP.description || 'Homestyle daily meals.',
                phone: dbP.public_phone,
                email: dbP.public_email || `${dbP.slug}@thali.mess`,
                address: `${dbP.address_line1}, ${dbP.locality ? dbP.locality + ', ' : ''}${dbP.city}`,
                locality: dbP.locality || dbP.city,
                city: dbP.city,
                rating: 5.0,
                total_reviews: 0,
                cuisines: ['North Indian', 'Homestyle'],
                dietary_types: ['veg'],
                status: dbP.status || 'active',
                created_at: dbP.created_at,
              };
              platformStore.providers.set(found.id, found);
            }
          }
        } catch {}
      }

      if (found) {
        providerData = found;
      }
    }

    const userId = authenticatedUserId || `usr-${resolvedRole}-${Buffer.from(authenticatedEmail).toString('hex').slice(0, 8)}`;
    const providerIdVal = providerData?.id || (resolvedRole === 'provider' ? (authenticatedUserId || userId) : undefined);
    const token = `jwt_session_${Buffer.from(
      JSON.stringify({
        userId,
        email: authenticatedEmail,
        role: resolvedRole,
        providerId: providerIdVal,
        provider_id: providerIdVal,
      })
    ).toString('base64url')}`;

    return NextResponse.json({
      success: true,
      user: {
        id: userId,
        email: authenticatedEmail,
        name: providerData ? providerData.display_name : authenticatedEmail.split('@')[0],
        role: resolvedRole,
        provider_id: providerData?.id,
        provider_name: providerData?.display_name,
      },
      provider: providerData,
      token,
      message: 'Login successful.',
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Login failed' },
      { status: 500 }
    );
  }
}
