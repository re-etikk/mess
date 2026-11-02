import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  let body: { refresh_token?: string };
  try { body = await req.json(); } catch { return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 }); }
  const refreshToken = body.refresh_token?.trim();
  if (!refreshToken) return NextResponse.json({ success: false, error: 'A refresh token is required.' }, { status: 400 });
  try {
    const supabase = await createClient();
    const { data, error } = await supabase.auth.refreshSession({ refresh_token: refreshToken });
    if (error || !data.session || !data.user) return NextResponse.json({ success: false, error: 'Session expired. Please sign in again.' }, { status: 401 });
    return NextResponse.json({ success: true, user: { id: data.user.id, email: data.user.email, name: data.user.user_metadata?.display_name || data.user.email?.split('@')[0] || '' },
      token: data.session.access_token, refresh_token: data.session.refresh_token, expires_at: data.session.expires_at }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    console.error('Mobile session refresh failed:', error instanceof Error ? error.message : 'unknown error');
    return NextResponse.json({ success: false, error: 'Session refresh is temporarily unavailable.' }, { status: 503 });
  }
}
