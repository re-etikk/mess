import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const supabase = await createClient();
    const { data, error } = await supabase
      .from('providers')
      .select('id,display_name,slug,description,logo_path,cover_path,public_phone,public_email,address_line1,locality,city,state,pincode,supports_pickup')
      .eq('status', 'active')
      .order('display_name', { ascending: true });
    if (error) throw error;

    return NextResponse.json({
      providers: (data ?? []).map((provider) => ({
        ...provider,
        is_open_today: null,
      })),
    }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('Public provider listing failed:', error instanceof Error ? error.message : 'unknown error');
    return NextResponse.json({ success: false, error: 'Listings are temporarily unavailable. Please retry.' }, { status: 503 });
  }
}
