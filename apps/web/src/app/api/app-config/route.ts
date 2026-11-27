import { NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { getPlatformAppConfig } from '@/lib/app-config';

export const dynamic = 'force-dynamic';

export async function GET() {
  const admin = getAdminClient();
  const config = await getPlatformAppConfig(admin);
  return NextResponse.json(
    { success: true, config },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}
