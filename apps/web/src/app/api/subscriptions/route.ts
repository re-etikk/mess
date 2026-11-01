import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';

export async function GET(req: NextRequest) {
  try {
    const bearer = req.headers.get('authorization')?.match(/^Bearer\s+(.+)$/i)?.[1];
    let user: { id: string } | null = null;
    if (bearer) {
      const admin = getAdminClient();
      if (!admin) return NextResponse.json({ success: false, error: 'Authentication is not configured.' }, { status: 503 });
      const { data, error } = await admin.auth.getUser(bearer);
      if (error || !data.user) return NextResponse.json({ success: false, error: 'Authentication required.' }, { status: 401 });
      user = data.user;
    } else {
      const supabase = await createClient();
      const { data, error } = await supabase.auth.getUser();
      if (error || !data.user) return NextResponse.json({ success: false, error: 'Authentication required.' }, { status: 401 });
      user = data.user;
    }
    const supabase = await createClient();
    const { data: subscriptions, error } = await supabase
      .from('subscriptions')
      .select('*')
      .eq('customer_id', user.id)
      .order('created_at', { ascending: false });
    if (error) return NextResponse.json({ success: false, error: 'Could not load subscriptions.' }, { status: 503 });
    return NextResponse.json({ success: true, total: subscriptions.length, subscriptions }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch {
    return NextResponse.json({ success: false, error: 'Subscriptions are temporarily unavailable.' }, { status: 503 });
  }
}

export async function POST() {
  return NextResponse.json({ success: false, code: 'payments_not_configured', error: 'Subscriptions can only be created by a verified payment webhook.' }, { status: 503 });
}
