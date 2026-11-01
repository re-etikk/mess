import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdmin } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

const ReviewSchema = z.object({
  provider_id: z.string().uuid(),
  decision: z.enum(['approve', 'reject']),
  reason: z.string().trim().max(500).default('Review completed.'),
});

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req);
  if (!auth.ok) return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  const includeActive = new URL(req.url).searchParams.get('all') === 'true';
  const base = auth.admin.from('providers')
    .select('id,owner_user_id,display_name,public_phone,public_email,description,address_line1,locality,city,state,pincode,created_at,status');
  const [pending, active] = await Promise.all([
    base.eq('status', 'pending_review').order('created_at', { ascending: false }),
    includeActive ? auth.admin.from('providers').select('id,owner_user_id,display_name,public_phone,public_email,description,address_line1,locality,city,state,pincode,created_at,status').eq('status', 'active').order('display_name') : Promise.resolve({ data: [], error: null }),
  ]);
  if (pending.error || active.error) {
    console.error('Provider review queue query failed:', pending.error?.message || active.error?.message);
    return NextResponse.json({ success: false, error: 'Provider records could not be loaded.' }, { status: 503 });
  }
  return NextResponse.json({ success: true, applications: pending.data ?? [], active_providers: active.data ?? [] }, { headers: { 'Cache-Control': 'private, no-store' } });
}

export async function PATCH(req: NextRequest) {
  const auth = await requireAdmin(req);
  if (!auth.ok) return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  let payload: unknown;
  try { payload = await req.json(); } catch { return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 }); }
  const parsed = ReviewSchema.safeParse(payload);
  if (!parsed.success) return NextResponse.json({ success: false, error: 'A valid provider ID and review decision are required.', details: parsed.error.flatten() }, { status: 400 });

  const { provider_id, decision, reason } = parsed.data;
  const approved = decision === 'approve';
  const { data: provider, error } = await auth.admin.from('providers').update({
    status: approved ? 'active' : 'rejected',
    approved_at: approved ? new Date().toISOString() : null,
    approved_by: approved ? auth.userId : null,
  }).eq('id', provider_id).eq('status', 'pending_review')
    .select('id,display_name,status,approved_at').maybeSingle();
  if (error) {
    console.error('Provider decision failed:', error.message);
    return NextResponse.json({ success: false, error: 'Provider decision could not be saved.' }, { status: 503 });
  }
  if (!provider) return NextResponse.json({ success: false, error: 'No pending application was found for this provider.' }, { status: 404 });

  const { error: auditError } = await auth.admin.from('audit_logs').insert({
    actor_user_id: auth.userId,
    action: approved ? 'provider.approved' : 'provider.rejected',
    subject_type: 'provider',
    subject_id: provider.id,
    reason: reason || null,
  });
  if (auditError) console.error('Provider decision audit write failed:', auditError.message);
  return NextResponse.json({ success: true, provider, decision, reason, message: `Provider ${decision}d.` });
}
