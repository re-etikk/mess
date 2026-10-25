import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function GET() {
  try {
    const supabase = await createClient();
    const { data, error } = await supabase
      .from('providers')
      .select('id,display_name,slug,description,logo_path,cover_path,public_phone,public_email,locality,city,state,pincode,supports_pickup')
      .eq('status', 'active')
      .order('display_name', { ascending: true });
    if (error) return NextResponse.json({ error: 'Live provider listings could not be loaded.' }, { status: 503 });
    return NextResponse.json({ providers: data ?? [] }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json({ error: 'Provider discovery is unavailable until the verified backend is configured.' }, { status: 503 });
  }
}
