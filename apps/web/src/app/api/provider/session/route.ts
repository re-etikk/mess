import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return NextResponse.json({ success: false, error: 'Sign in to continue.' }, { status: 401 });

    const { data: memberships, error: membershipError } = await supabase.from('provider_memberships')
      .select('provider_id,role').eq('user_id', user.id).eq('active', true)
      .in('role', ['owner', 'manager']).order('created_at', { ascending: true }).limit(1);
    if (membershipError) throw membershipError;
    const membership = memberships?.[0];
    if (!membership) return NextResponse.json({ success: true, authenticated: true, provider: null });

    const { data: provider, error: providerError } = await supabase.from('providers')
      .select('id,display_name,public_phone,status,slug').eq('id', membership.provider_id).maybeSingle();
    if (providerError) throw providerError;
    if (!provider) return NextResponse.json({ success: false, error: 'Your partner profile could not be loaded.' }, { status: 503 });

    const { data: profile } = await supabase.from('profiles').select('display_name,phone_e164').eq('id', user.id).maybeSingle();
    return NextResponse.json({ success: true, authenticated: true, provider: {
      id: provider.id,
      name: provider.display_name,
      phone: provider.public_phone || profile?.phone_e164 || '',
      email: user.email || '',
      status: provider.status,
      role: membership.role,
    } }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('Partner session lookup failed:', error instanceof Error ? error.message : 'unknown error');
    return NextResponse.json({ success: false, error: 'Partner access could not be verified.' }, { status: 503 });
  }
}
