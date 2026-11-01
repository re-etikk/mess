import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';

export async function POST(req: NextRequest) {
  let body: { email?: string; password?: string; role?: string; name?: string; display_name?: string; phone?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 });
  }

  const email = body.email?.trim().toLowerCase();
  const password = body.password;
  const name = (body.name || body.display_name || '').trim();
  const phone = body.phone?.trim() || null;
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || !password || password.length < 8 || name.length < 2) {
    return NextResponse.json({ success: false, error: 'Enter a valid email, name, and password of at least 8 characters.' }, { status: 400 });
  }
  if (body.role && body.role !== 'customer') {
    return NextResponse.json({ success: false, error: 'Provider applications must use the partner onboarding flow. Admin accounts cannot self-register.' }, { status: 403 });
  }

  const admin = getAdminClient();
  if (!admin) return NextResponse.json({ success: false, error: 'Registration is unavailable until server-side Supabase credentials are configured.' }, { status: 503 });

  try {
    const supabase = await createClient();
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { display_name: name, phone } },
    });
    if (error || !data.user) {
      return NextResponse.json({ success: false, error: error?.message || 'Account could not be created.' }, { status: 400 });
    }
    if ((data.user.identities ?? []).length === 0) {
      return NextResponse.json({ success: false, error: 'An account with this email may already exist. Please sign in or recover access.' }, { status: 409 });
    }

    const { error: profileError } = await admin.from('profiles').insert({ id: data.user.id, display_name: name, phone_e164: phone });
    const { data: existingRole, error: existingRoleError } = await admin.from('user_roles')
      .select('id,revoked_at').eq('user_id', data.user.id).eq('role', 'customer').maybeSingle();
    const roleResult = existingRoleError
      ? { error: existingRoleError }
      : existingRole
        ? existingRole.revoked_at
          ? await admin.from('user_roles').update({ revoked_at: null }).eq('id', existingRole.id)
          : { error: null }
        : await admin.from('user_roles').insert({ user_id: data.user.id, role: 'customer' });
    if (profileError || roleResult.error) {
      console.error('Account provisioning failed', { profileError: profileError?.message, roleError: roleResult.error?.message });
      return NextResponse.json({ success: false, error: 'Account was created but profile setup failed. Contact support before retrying.' }, { status: 503 });
    }

    return NextResponse.json({
      success: true,
      user: { id: data.user.id, email: data.user.email, name, role: 'customer', phone },
      session_created: Boolean(data.session),
      message: data.session ? 'Registration successful.' : 'Check your email to confirm your account before signing in.',
    }, { status: 201 });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Registration is unavailable.';
    return NextResponse.json({ success: false, error: message }, { status: 503 });
  }
}
