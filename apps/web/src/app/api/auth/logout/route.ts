import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function POST() {
  let signOutErr = false;
  try {
    const supabase = await createClient();
    const { error } = await supabase.auth.signOut();
    if (error) signOutErr = true;
  } catch {
    signOutErr = true;
  }

  const res = NextResponse.json(
    signOutErr ? { success: true, cleared: true } : { success: true }
  );
  res.cookies.set('thali_session_token', '', {
    httpOnly: true,
    sameSite: 'lax',
    path: '/',
    maxAge: 0,
  });
  return res;
}
