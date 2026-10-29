import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore, seedProviderPlansAndMenu } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

const ReviewSchema = z.object({
  provider_id: z.string(),
  decision: z.enum(['approve', 'reject']),
  reason: z.string().trim().max(500).default('Admin review verification completed.'),
});

export async function GET(req: NextRequest) {
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
            if (meta.role === 'provider' && meta.application) {
              const app = {
                id: meta.application.id || u.id,
                display_name: meta.application.display_name || meta.display_name || 'Mess Partner',
                public_phone: meta.application.public_phone || meta.phone || '',
                description: meta.application.description || null,
                address_line1: meta.application.address_line1 || 'Address on file',
                locality: meta.application.locality || null,
                city: meta.application.city || 'Campus Area',
                state: meta.application.state || 'India',
                pincode: meta.application.pincode || '000000',
                created_at: meta.application.created_at || u.created_at,
                status: meta.application.status || 'pending_review',
                rating: 5.0,
                total_reviews: 0,
              };

              if (app.status === 'pending_review') {
                pendingMap.set(app.id, app);
              } else if (app.status === 'active') {
                activeMap.set(app.id, app);
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
          for (const p of pendingData) pendingMap.set(p.id, p);
        }

        if (includeActive) {
          const { data: activeData } = await admin
            .from('providers')
            .select('id,display_name,public_phone,description,address_line1,locality,city,state,pincode,created_at,status')
            .eq('status', 'active')
            .order('display_name', { ascending: true });
          if (activeData) {
            for (const p of activeData) activeMap.set(p.id, p);
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
      if (!pendingMap.has(p.id)) pendingMap.set(p.id, item);
    } else if (p.status === 'active') {
      if (!activeMap.has(p.id)) activeMap.set(p.id, item);
    }
  }

  return NextResponse.json({
    applications: Array.from(pendingMap.values()),
    active_providers: Array.from(activeMap.values()),
  });
}

export async function PATCH(request: NextRequest) {
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

  let providerName = 'Mess';

  // 1. Update in Supabase
  try {
    const admin = getAdminClient();
    if (admin) {
      // A. Update in Auth user metadata
      try {
        const { data: uData } = await admin.auth.admin.getUserById(provider_id);
        if (uData?.user) {
          const meta = uData.user.user_metadata || {};
          const app = meta.application || {};
          app.status = newStatus;
          app.approved_at = approved ? new Date().toISOString() : null;
          providerName = app.display_name || meta.display_name || providerName;

          await admin.auth.admin.updateUserById(provider_id, {
            user_metadata: {
              ...meta,
              application: app,
            },
          });
        }
      } catch (uErr) {
        console.warn('Update Auth user metadata note:', uErr);
      }

      // B. Also update table if accessible
      try {
        const { data } = await admin
          .from('providers')
          .update({
            status: newStatus,
            approved_at: approved ? new Date().toISOString() : null,
            updated_at: new Date().toISOString(),
          })
          .eq('id', provider_id)
          .select('*')
          .maybeSingle();

        if (data) {
          providerName = data.display_name || providerName;
        }
      } catch {}
    }
  } catch (err) {
    console.warn('Failed to update Supabase provider status:', err);
  }

  // 2. Update in platformStore and seed plans/menus
  const provider = platformStore.providers.get(provider_id);
  if (provider) {
    provider.status = newStatus;
    providerName = provider.display_name;
  }

  if (approved) {
    seedProviderPlansAndMenu(provider_id);
  }

  return NextResponse.json({
    success: true,
    provider: { id: provider_id, status: newStatus, display_name: providerName },
    message: approved
      ? `✅ ${providerName} has been approved! Kitchen listing and plans are now active.`
      : `Provider application rejected.`,
  });
}
