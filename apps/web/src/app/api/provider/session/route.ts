import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { verifySignedSessionToken } from '@/lib/auth-session';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  try {
    let userId = '';
    let userEmail = '';

    try {
      const supabase = await createClient();
      const {
        data: { user },
        error: authError,
      } = await supabase.auth.getUser();
      if (!authError && user) {
        userId = user.id;
        userEmail = user.email || '';
      }
    } catch {}

    if (!userId) {
      const cookieToken = req.cookies.get('thali_session_token')?.value?.trim();
      const verified = cookieToken ? verifySignedSessionToken(cookieToken, 'thali_tok_') : null;
      if (verified) {
        userId = verified.userId;
        userEmail = verified.email || '';
      }
    }

    if (!userId) {
      return NextResponse.json({ success: false, error: 'Sign in to continue.' }, { status: 401 });
    }

    const db = getAdminClient() || (await createClient());

    const { data: memberships, error: membershipError } = await db
      .from('provider_memberships')
      .select('provider_id,role')
      .eq('user_id', userId)
      .eq('active', true)
      .in('role', ['owner', 'manager'])
      .order('created_at', { ascending: true })
      .limit(1);

    if (membershipError) throw membershipError;
    let membership = memberships?.[0];

    let provider: any = null;
    if (membership?.provider_id) {
      const { data: provRow } = await db
        .from('providers')
        .select('id,display_name,public_phone,status,slug')
        .eq('id', membership.provider_id)
        .maybeSingle();
      provider = provRow;
    } else {
      const { data: owned } = await db
        .from('providers')
        .select('id,display_name,public_phone,status,slug')
        .eq('owner_user_id', userId)
        .limit(1)
        .maybeSingle();
      if (owned) {
        provider = owned;
        membership = { provider_id: owned.id, role: 'owner' };
      }
    }

    if (!provider) {
      return NextResponse.json({ success: true, authenticated: true, provider: null });
    }

    const { data: profile } = await db
      .from('profiles')
      .select('display_name,phone_e164')
      .eq('id', userId)
      .maybeSingle();

    return NextResponse.json(
      {
        success: true,
        authenticated: true,
        provider: {
          id: provider.id,
          name: provider.display_name,
          phone: provider.public_phone || profile?.phone_e164 || '',
          email: userEmail,
          status: provider.status,
          role: membership?.role || 'owner',
        },
      },
      { headers: { 'Cache-Control': 'private, no-store' } }
    );
  } catch (error) {
    console.error('Partner session lookup failed:', error instanceof Error ? error.message : 'unknown error');
    return NextResponse.json({ success: false, error: 'Partner access could not be verified.' }, { status: 503 });
  }
}
