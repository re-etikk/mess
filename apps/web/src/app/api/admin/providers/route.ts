import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getAdminClient, requireAdmin } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { sendProviderApprovalNotice } from '@/lib/notifications';

export const dynamic = 'force-dynamic';

const ReviewSchema = z.object({
  provider_id: z.string(),
  decision: z.enum(['approve', 'reject']),
  reason: z.string().trim().max(500).default('Admin review verification completed.'),
});

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }

  const { searchParams } = new URL(req.url);
  const includeActive = searchParams.get('all') === 'true';

  const pendingMap = new Map<string, any>();
  const activeMap = new Map<string, any>();

  try {
    const admin = getAdminClient();
    if (admin) {
      // 1. Read persistent applications from Supabase Auth users metadata
      try {
        const { data: usersData } = await admin.auth.admin.listUsers({ perPage: 100 });
        if (usersData?.users) {
          for (const u of usersData.users) {
            const meta = u.user_metadata || {};
            if (meta.application || meta.role === 'provider' || meta.display_name) {
              const appData = meta.application || {};
              const status = appData.status || meta.status || 'pending_review';
              const appId = appData.id || u.id;
              const app = {
                id: appId,
                auth_user_id: u.id,
                display_name: appData.display_name || meta.display_name || 'Mess Partner',
                public_phone: appData.public_phone || meta.phone || u.phone || '',
                email: appData.email || meta.email || u.email || '',
                description: appData.description || meta.description || null,
                address_line1: appData.address_line1 || 'Address on file',
                locality: appData.locality || null,
                city: appData.city || 'Campus Area',
                state: appData.state || 'India',
                pincode: appData.pincode || '000000',
                created_at: appData.created_at || u.created_at,
                status,
                rating: 5.0,
                total_reviews: 0,
              };

              if (status === 'pending_review') {
                pendingMap.set(appId, app);
              } else if (status === 'active') {
                activeMap.set(appId, app);
                pendingMap.delete(appId);
                pendingMap.delete(u.id);
                if (appData.id) pendingMap.delete(appData.id);
                if (appData.provider_id) pendingMap.delete(appData.provider_id);
              }
            }
          }
        }
      } catch (authErr) {
        console.warn('Supabase Auth listUsers note:', authErr);
      }

      // 2. Also read from public.providers table if accessible
      try {
        const { data: pendingData } = await admin
          .from('providers')
          .select('id,display_name,public_phone,description,address_line1,locality,city,state,pincode,created_at,status')
          .eq('status', 'pending_review')
          .order('created_at', { ascending: false });

        if (pendingData) {
          for (const p of pendingData) {
            if (!activeMap.has(p.id)) pendingMap.set(p.id, p);
          }
        }

        if (includeActive) {
          const { data: activeData } = await admin
            .from('providers')
            .select('id,display_name,public_phone,description,address_line1,locality,city,state,pincode,created_at,status')
            .eq('status', 'active')
            .order('display_name', { ascending: true });
          if (activeData) {
            for (const p of activeData) {
              activeMap.set(p.id, p);
              pendingMap.delete(p.id);
            }
          }
        }
      } catch {
        // Table permissions fallback handled
      }
    }
  } catch (err) {
    console.warn('Failed to query Supabase admin providers:', err);
  }

  // 3. Merge with in-memory platformStore
  for (const p of platformStore.providers.values()) {
    const item = {
      id: p.id,
      display_name: p.display_name,
      public_phone: p.phone,
      description: p.description,
      address_line1: p.address,
      locality: p.locality,
      city: p.city,
      state: 'India',
      pincode: '000000',
      created_at: p.created_at,
      status: p.status,
      rating: p.rating,
      total_reviews: p.total_reviews,
    };
    if (p.status === 'pending_review') {
      if (!activeMap.has(p.id) && !pendingMap.has(p.id)) {
        pendingMap.set(p.id, item);
      }
    } else if (p.status === 'active') {
      if (!activeMap.has(p.id)) activeMap.set(p.id, item);
      pendingMap.delete(p.id);
    }
  }

  return NextResponse.json({
    applications: Array.from(pendingMap.values()).filter((a) => a.status === 'pending_review'),
    active_providers: Array.from(activeMap.values()),
  });
}

export async function PATCH(request: NextRequest) {
  const auth = await requireAdmin(request);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body.' }, { status: 400 });
  }

  const parsed = ReviewSchema.safeParse(payload);
  if (!parsed.success) {
    return NextResponse.json({ error: 'A valid decision and provider ID are required.' }, { status: 400 });
  }

  const { provider_id, decision } = parsed.data;
  const approved = decision === 'approve';
  const newStatus = approved ? 'active' : 'rejected';

  let providerName = 'Mess Partner';
  let matchedAuthUser: any = null;

  // 1. Resiliently locate and update provider in Supabase GoTrue Auth
  try {
    const admin = getAdminClient();
    if (admin) {
      // Step A: Try direct ID lookup
      try {
        const { data: uData } = await admin.auth.admin.getUserById(provider_id);
        if (uData?.user) {
          matchedAuthUser = uData.user;
        }
      } catch {}

      // Step B: Search listUsers if direct lookup missed (e.g. provider_id is application.id UUID)
      if (!matchedAuthUser) {
        try {
          const { data: listData } = await admin.auth.admin.listUsers({ perPage: 100 });
          if (listData?.users) {
            matchedAuthUser = listData.users.find((u) => {
              const meta = u.user_metadata || {};
              const app = meta.application || {};
              return (
                u.id === provider_id ||
                app.id === provider_id ||
                app.provider_id === provider_id ||
                meta.phone === provider_id ||
                app.public_phone === provider_id ||
                u.email === provider_id ||
                meta.email === provider_id
              );
            });
          }
        } catch (lErr) {
          console.warn('Auth listUsers search note:', lErr);
        }
      }

      // Step C: Update GoTrue user metadata to active
      if (matchedAuthUser) {
        const meta = matchedAuthUser.user_metadata || {};
        const app = meta.application || {};
        app.status = newStatus;
        app.approved_at = approved ? new Date().toISOString() : null;
        providerName = app.display_name || meta.display_name || providerName;

        try {
          await admin.auth.admin.updateUserById(matchedAuthUser.id, {
            user_metadata: {
              ...meta,
              role: 'provider',
              status: newStatus,
              application: app,
            },
          });
        } catch (uErr) {
          console.warn('Update Auth user metadata note:', uErr);
        }
      }

      // Step D: Also update public.providers table if accessible
      const candidateIds = [provider_id];
      if (matchedAuthUser?.id && matchedAuthUser.id !== provider_id) {
        candidateIds.push(matchedAuthUser.id);
      }
      for (const cid of candidateIds) {
        try {
          const { data } = await admin
            .from('providers')
            .update({
              status: newStatus,
              approved_at: approved ? new Date().toISOString() : null,
              updated_at: new Date().toISOString(),
            })
            .eq('id', cid)
            .select('*')
            .maybeSingle();

          if (data?.display_name) {
            providerName = data.display_name;
          }
        } catch {}
      }
    }
  } catch (err) {
    console.warn('Failed to update Supabase provider status:', err);
  }

  // 2. Update in platformStore and seed plans/menus
  const candidateIds = [provider_id];
  if (matchedAuthUser?.id && matchedAuthUser.id !== provider_id) {
    candidateIds.push(matchedAuthUser.id);
  }

  for (const cid of candidateIds) {
    const provider = platformStore.providers.get(cid);
    if (provider) {
      provider.status = newStatus;
      providerName = provider.display_name;
    }
  }

  // 3. Dispatch automated Email and SMS notification with User ID and Password
  let notificationResult = null;
  if (approved) {
    const meta = matchedAuthUser?.user_metadata || {};
    const app = meta.application || {};
    const phone = meta.phone || app.public_phone || matchedAuthUser?.phone || '';
    const email = meta.email || app.email || matchedAuthUser?.email || '';
    const password = meta.initial_password || meta.login_password || 'MessOwner@2026';
    const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://mess-beta.vercel.app';

    try {
      notificationResult = await sendProviderApprovalNotice({
        provider_name: providerName,
        phone,
        email,
        user_id: phone.replace(/\D/g, '').slice(-10) || matchedAuthUser?.id || provider_id,
        password,
        login_url: `${siteUrl}/auth/login`,
      });
    } catch (notifErr) {
      console.warn('Provider approval notification note:', notifErr);
    }
  }

  return NextResponse.json({
    success: true,
    provider: { id: provider_id, status: newStatus, display_name: providerName },
    notification: notificationResult,
    message: approved
      ? `✅ ${providerName} has been approved! Kitchen listing & plans are now active.`
      : `Provider application rejected.`,
  });
}

export const POST = PATCH;
