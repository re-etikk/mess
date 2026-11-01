import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function POST() {
  try {
    const supabase = await createClient();
    const { error } = await supabase.auth.signOut();
    if (error) return NextResponse.json({ success: false, error: 'Could not end the session.' }, { status: 503 });
    return NextResponse.json({ success: true });
  } catch {
    return NextResponse.json({ success: false, error: 'Authentication is unavailable.' }, { status: 503 });
  }
}
