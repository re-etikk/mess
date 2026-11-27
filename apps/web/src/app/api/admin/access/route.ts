import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdmin } from '@/lib/supabase/admin';
import { logAdminAudit } from '@/lib/admin-rbac';

export const dynamic = 'force-dynamic';

const GrantRoleSchema = z.object({
  email: z.string().trim().email(),
  admin_role: z.enum(['super_admin', 'operations', 'finance', 'support', 'developer_readonly']),
  reason: z.string().trim().min(3).max(400),
});

const RevokeRoleSchema = z.object({
  user_id: z.string().uuid(),
  reason: z.string().trim().min(3).max(400),
});

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req, 'access.manage');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const [rolesRes, permsRes] = await Promise.all([
    access.admin
      .from('user_roles')
      .select('user_id,role,granted_at,revoked_at,profiles:user_id(display_name,email)')
      .in('role', ['admin', 'support'])
      .order('granted_at', { ascending: false }),
    access.admin
      .from('admin_team_permissions')
      .select('user_id,admin_role,granted_by,revoked_at,created_at')
      .then((r) => r, () => ({ data: [], error: null })),
  ]);

  const permsMap = new Map<string, any>();
  for (const p of permsRes.data ?? []) {
    permsMap.set(String(p.user_id), p);
  }

  const seen = new Set<string>();
  const team: any[] = [];
  for (const r of rolesRes.data ?? []) {
    const uid = String(r.user_id);
    if (seen.has(uid)) continue;
    seen.add(uid);
    const perm = permsMap.get(uid);
    const baseRole = r.role === 'support' ? 'support' : 'super_admin';
    const isRevoked = Boolean(r.revoked_at) || Boolean(perm?.revoked_at);
    team.push({
      user_id: uid,
      name: (r.profiles as any)?.display_name || 'Team Member',
      email: (r.profiles as any)?.email || '',
      db_role: r.role,
      admin_role: perm?.admin_role || baseRole,
      active: !isRevoked,
      granted_at: r.granted_at,
    });
  }

  return NextResponse.json(
    { success: true, caller_role: access.adminRole, team },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function POST(req: NextRequest) {
  const access = await requireAdmin(req, 'access.manage');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const body = await req.json().catch(() => ({}));
  const parsed = GrantRoleSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ success: false, error: 'Valid email, role, and reason are required.' }, { status: 400 });
  }

  const { email, admin_role, reason } = parsed.data;
  const { data: profile } = await access.admin
    .from('profiles')
    .select('id,display_name,email')
    .ilike('email', email)
    .maybeSingle();

  if (!profile?.id) {
    return NextResponse.json(
      { success: false, error: 'No registered user found with that email. Ask them to register an account first.' },
      { status: 404 }
    );
  }

  const appRole = admin_role === 'support' ? 'support' : 'admin';
  await access.admin
    .from('user_roles')
    .upsert({ user_id: profile.id, role: appRole, granted_by: access.userId, revoked_at: null }, { onConflict: 'user_id,role' });

  const { error: permErr } = await access.admin
    .from('admin_team_permissions')
    .upsert(
      {
        user_id: profile.id,
        admin_role,
        granted_by: access.userId,
        revoked_at: null,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'user_id' }
    );

  if (permErr) {
    console.warn('admin_team_permissions upsert warning:', permErr.message);
  }

  await logAdminAudit(access.admin, {
    actorUserId: access.userId,
    action: 'access.role_granted',
    subjectType: 'profile',
    subjectId: profile.id,
    reason,
    details: { email, admin_role },
  });

  return NextResponse.json({ success: true, message: `Granted ${admin_role} access to ${email}.` });
}

export async function DELETE(req: NextRequest) {
  const access = await requireAdmin(req, 'access.manage');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const body = await req.json().catch(() => ({}));
  const parsed = RevokeRoleSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ success: false, error: 'Valid user ID and reason are required.' }, { status: 400 });
  }

  const { user_id, reason } = parsed.data;
  if (user_id === access.userId) {
    return NextResponse.json({ success: false, error: 'You cannot revoke your own active administrator role.' }, { status: 400 });
  }

  const nowIso = new Date().toISOString();
  await access.admin
    .from('user_roles')
    .update({ revoked_at: nowIso })
    .eq('user_id', user_id)
    .in('role', ['admin', 'support']);

  await access.admin
    .from('admin_team_permissions')
    .update({ revoked_at: nowIso })
    .eq('user_id', user_id)
    .then(() => null, () => null);

  await logAdminAudit(access.admin, {
    actorUserId: access.userId,
    action: 'access.role_revoked',
    subjectType: 'profile',
    subjectId: user_id,
    reason,
  });

  return NextResponse.json({ success: true, message: 'Administrator access revoked.' });
}
