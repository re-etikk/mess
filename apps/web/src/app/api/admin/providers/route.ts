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

  let supabaseApps: any[] = [];
  let supabaseActive: any[] = [];

  try {
    const admin = getAdminClient();
    if (admin) {
      const { data: pendingData } = await admin
        .from('providers')
        .select('id,display_name,public_phone,description,address_line1,locality,city,state,pincode,created_at,status')
        .eq('status', 'pending_review')
        .order('created_at', { ascending: false });

      if (pendingData) supabaseApps = pendingData;

      if (includeActive) {
        const { data: activeData } = await admin
          .from('providers')
          .select('id,display_name,public_phone,description,address_line1,locality,city,state,pincode,created_at,status')
          .eq('status', 'active')
          .order('display_name', { ascending: true });
        if (activeData) supabaseActive = activeData;
      }
    }
  } catch (err) {
    console.warn('Failed to query Supabase admin providers:', err);
  }

  // Also read from platformStore
  const storePending = Array.from(platformStore.providers.values())
    .filter((p) => p.status === 'pending_review')
    .map((p) => ({
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
    }));

  const storeActive = Array.from(platformStore.providers.values())
    .filter((p) => p.status === 'active')
    .map((p) => ({
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
    }));

  const allPendingMap = new Map<string, any>();
  for (const app of storePending) allPendingMap.set(app.id, app);
  for (const app of supabaseApps) allPendingMap.set(app.id, app);

  const allActiveMap = new Map<string, any>();
  for (const p of storeActive) allActiveMap.set(p.id, p);
  for (const p of supabaseActive) allActiveMap.set(p.id, p);

  return NextResponse.json({
    applications: Array.from(allPendingMap.values()),
    active_providers: Array.from(allActiveMap.values()),
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

  let updatedRecord: any = null;

  // 1. Update in Supabase
  try {
    const admin = getAdminClient();
    if (admin) {
      const { data, error } = await admin
        .from('providers')
        .update({
          status: newStatus,
          approved_at: approved ? new Date().toISOString() : null,
          updated_at: new Date().toISOString(),
        })
        .eq('id', provider_id)
        .select('*')
        .maybeSingle();

      if (!error && data) {
        updatedRecord = data;
        // Keep platformStore in sync
        platformStore.providers.set(data.id, {
          id: data.id,
          owner_user_id: data.owner_user_id,
          display_name: data.display_name,
          slug: data.slug,
          description: data.description || 'Homestyle daily meals.',
          phone: data.public_phone,
          email: data.public_email || `${data.slug}@thali.mess`,
          address: `${data.address_line1}, ${data.locality ? data.locality + ', ' : ''}${data.city}`,
          locality: data.locality || data.city,
          city: data.city,
          rating: 5.0,
          total_reviews: 0,
          cuisines: ['North Indian', 'Homestyle'],
          dietary_types: ['veg'],
          status: 'active',
          created_at: data.created_at,
        });
      } else if (error) {
        console.error('Supabase provider status update error:', error);
      }
    }
  } catch (err) {
    console.warn('Failed to update Supabase provider status:', err);
  }

  // 2. Update in platformStore
  const provider = platformStore.providers.get(provider_id);
  if (provider) {
    provider.status = newStatus;
    if (approved) {
      seedProviderPlansAndMenu(provider.id);
    }
    return NextResponse.json({
      success: true,
      provider,
      message: approved
        ? `✅ ${provider.display_name} has been approved! Kitchen listing and plans are now active.`
        : `Provider application rejected.`,
    });
  }

  if (updatedRecord) {
    if (approved) {
      seedProviderPlansAndMenu(updatedRecord.id);
    }
    return NextResponse.json({
      success: true,
      provider: updatedRecord,
      message: approved
        ? `✅ ${updatedRecord.display_name} has been approved! Kitchen listing and plans are now active.`
        : `Provider application rejected.`,
    });
  }

  if (approved) {
    seedProviderPlansAndMenu(provider_id);
  }

  return NextResponse.json({
    success: true,
    provider: { id: provider_id, status: newStatus },
    message: `Provider updated to ${newStatus}.`,
  });
}
