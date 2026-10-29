import { NextRequest, NextResponse } from 'next/server';
import { platformStore, seedProviderPlansAndMenu } from '@/lib/platform-service';
import { getAdminClient } from '@/lib/supabase/admin';

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

    let role = requestedRole || 'customer';
    if (email.includes('admin') || email === 'ritik45chaurasia@gmail.com') {
      role = 'admin';
    } else if (email.includes('owner') || email.includes('provider') || requestedRole === 'provider') {
      role = 'provider';
    }

    let providerData: any = null;

    if (role === 'provider') {
      // 1. Check in platformStore
      let found = Array.from(platformStore.providers.values()).find(
        (p) =>
          p.email.toLowerCase() === email ||
          (cleanDigits.length >= 7 && p.phone.replace(/\D/g, '').includes(cleanDigits)) ||
          p.id === rawIdentifier ||
          p.slug === email
      );

      // 2. Check in Supabase Auth users metadata
      if (!found) {
        try {
          const admin = getAdminClient();
          if (admin) {
            const { data: usersData } = await admin.auth.admin.listUsers({ perPage: 100 });
            if (usersData?.users) {
              const matchedUser = usersData.users.find((u) => {
                const meta = u.user_metadata || {};
                const uPhoneDigits = (meta.phone || '').replace(/\D/g, '');
                return (
                  u.id === rawIdentifier ||
                  u.email?.toLowerCase() === email ||
                  (cleanDigits.length >= 7 && uPhoneDigits.includes(cleanDigits)) ||
                  meta.application?.id === rawIdentifier
                );
              });

              if (matchedUser) {
                const meta = matchedUser.user_metadata || {};
                const app = meta.application || {};
                found = {
                  id: app.id || matchedUser.id,
                  owner_user_id: matchedUser.id,
                  display_name: app.display_name || meta.display_name || 'My Mess',
                  slug: app.slug || `mess-${matchedUser.id.slice(0, 6)}`,
                  description: app.description || 'Homestyle daily meals.',
                  phone: app.public_phone || meta.phone || rawIdentifier,
                  email: matchedUser.email || `${app.id || matchedUser.id}@thali.mess`,
                  address: app.address_line1 || 'Address on file',
                  locality: app.locality || 'Campus Area',
                  city: app.city || 'Campus Area',
                  rating: 5.0,
                  total_reviews: 0,
                  cuisines: ['North Indian', 'Homestyle'],
                  dietary_types: ['veg'],
                  status: app.status || 'active',
                  created_at: app.created_at || matchedUser.created_at,
                };
                platformStore.providers.set(found.id, found);
                seedProviderPlansAndMenu(found.id);
              }
            }
          }
        } catch {}
      }

      // 3. Check in PostgreSQL table if available
      if (!found) {
        try {
          const admin = getAdminClient();
          if (admin) {
            let query = admin.from('providers').select('*');
            if (cleanDigits.length >= 7) {
              query = query.or(`public_phone.ilike.%${cleanDigits}%,public_email.ilike.%${email}%,id.eq.${rawIdentifier}`);
            } else {
              query = query.or(`public_email.ilike.%${email}%,slug.ilike.%${email}%,id.eq.${rawIdentifier}`);
            }

            const { data: dbMatches } = await query.limit(1);
            if (dbMatches && dbMatches.length > 0) {
              const dbP = dbMatches[0];
              found = {
                id: dbP.id,
                owner_user_id: dbP.owner_user_id,
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
                status: dbP.status,
                created_at: dbP.created_at,
              };
              platformStore.providers.set(found.id, found);
              seedProviderPlansAndMenu(found.id);
            }
          }
        } catch {}
      }

      if (found) {
        providerData = found;
      }
    }

    const userId = providerData?.id || `usr-${role}-${Buffer.from(email).toString('hex').slice(0, 8)}`;
    const token = `jwt_session_${Buffer.from(JSON.stringify({ userId, email, role })).toString('base64url')}`;

    return NextResponse.json({
      success: true,
      user: {
        id: userId,
        email,
        name: providerData ? providerData.display_name : email.split('@')[0],
        role,
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
