import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdmin } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

const ReviewSchema = z.object({
  provider_id: z.string().uuid(),
  decision: z.enum(['approve', 'reject']),
  reason: z.string().trim().min(3).max(500),
});

export async function GET() {
  const access = await requireAdmin();
  if (!access.ok) return NextResponse.json({ error: access.error }, { status: access.status });
  const { data, error } = await access.admin
    .from('providers')
    .select('id,display_name,public_phone,description,address_line1,locality,city,state,pincode,created_at')
    .eq('status', 'pending_review')
    .order('created_at', { ascending: true });
  if (error) return NextResponse.json({ error: 'Provider application records could not be loaded.' }, { status: 503 });
  return NextResponse.json({ applications: data ?? [] });
}

export async function PATCH(request: NextRequest) {
  const access = await requireAdmin();
  if (!access.ok) return NextResponse.json({ error: access.error }, { status: access.status });
  let payload: unknown;
  try { payload = await request.json(); } catch { return NextResponse.json({ error: 'Invalid JSON body.' }, { status: 400 }); }
  const parsed = ReviewSchema.safeParse(payload);
  if (!parsed.success) return NextResponse.json({ error: 'A valid decision and review reason are required.' }, { status: 400 });

  const approved = parsed.data.decision === 'approve';
  const { data, error } = await access.admin
    .from('providers')
    .update({
      status: approved ? 'active' : 'rejected',
      approved_at: approved ? new Date().toISOString() : null,
      approved_by: approved ? access.userId : null,
      resolution_note: parsed.data.reason,
      resolved_at: new Date().toISOString(),
    })
    .eq('id', parsed.data.provider_id)
    .eq('status', 'pending_review')
    .select('id,display_name,status')
    .maybeSingle();
  if (error) return NextResponse.json({ error: 'Provider review could not be saved.' }, { status: 503 });
  if (!data) return NextResponse.json({ error: 'Application is no longer pending; refresh the queue.' }, { status: 409 });

  const { error: auditError } = await access.admin.from('audit_logs').insert({
    actor_user_id: access.userId,
    action: approved ? 'provider_application_approved' : 'provider_application_rejected',
    subject_type: 'provider',
    subject_id: data.id,
    reason: parsed.data.reason,
    sanitized_details: { status: data.status },
  });
  if (auditError) return NextResponse.json({ error: 'Decision saved, but the audit record failed. Inspect logs before retrying.' }, { status: 500 });
  return NextResponse.json({ provider: data });
}
