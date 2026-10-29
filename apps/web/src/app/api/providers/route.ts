import { NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const admin = getAdminClient();
    if (admin) {
      const { data, error } = await admin
        .from('providers')
        .select('id,display_name,slug,description,logo_path,cover_path,public_phone,public_email,locality,city,state,pincode,supports_pickup')
        .eq('status', 'active')
        .order('display_name', { ascending: true });

      if (!error && data && data.length > 0) {
        return NextResponse.json({ providers: data }, { headers: { 'Cache-Control': 'no-store' } });
      }
    }
  } catch {
    // Fallback to in-memory store
  }

  const activeProviders = Array.from(platformStore.providers.values()).filter(
    (p) => p.status === 'active'
  );

  return NextResponse.json(
    { providers: activeProviders },
    { headers: { 'Cache-Control': 'no-store' } }
  );
}
