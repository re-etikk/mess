import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdmin } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

const ReviewSchema = z.object({
  provider_id: z.string(),
  decision: z.enum(['approve', 'reject']),
  reason: z.string().trim().min(3).max(500),
});

export async function GET() {
  try {
    const access = await requireAdmin();
    if (access.ok) {
      const { data, error } = await access.admin
        .from('providers')
        .select('id,display_name,public_phone,description,address_line1,locality,city,state,pincode,created_at')
        .eq('status', 'pending_review')
        .order('created_at', { ascending: true });
      if (!error && data) {
        return NextResponse.json({ applications: data });
      }
    }
  } catch {
    // fallback
  }

  const applications = Array.from(platformStore.providers.values()).filter(
    (p) => p.status === 'pending_review'
  );

  return NextResponse.json({ applications });
}

export async function PATCH(request: NextRequest) {
  let payload: unknown;
  try { payload = await request.json(); } catch { return NextResponse.json({ error: 'Invalid JSON body.' }, { status: 400 }); }
  const parsed = ReviewSchema.safeParse(payload);
  if (!parsed.success) return NextResponse.json({ error: 'A valid decision and review reason are required.' }, { status: 400 });

  const approved = parsed.data.decision === 'approve';

  try {
    const access = await requireAdmin();
    if (access.ok) {
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
        .select('id,display_name,status')
        .maybeSingle();

      if (!error && data) {
        await access.admin.from('audit_logs').insert({
          actor_user_id: access.userId,
          action: approved ? 'provider_application_approved' : 'provider_application_rejected',
          subject_type: 'provider',
          subject_id: data.id,
          reason: parsed.data.reason,
          sanitized_details: { status: data.status },
        });
        return NextResponse.json({ provider: data });
      }
    }
  } catch {
    // fallback
  }

  const provider = platformStore.providers.get(parsed.data.provider_id);
  if (provider) {
    provider.status = approved ? 'active' : 'rejected';
    return NextResponse.json({ provider });
  }

  return NextResponse.json({ error: 'Provider not found.' }, { status: 404 });
}
