import { createBrowserClient } from '@supabase/ssr';

export function createClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (process.env.NEXT_PUBLIC_BACKEND_ENABLED !== 'true' || !supabaseUrl || !supabaseAnonKey) {
    throw new Error('Authentication is unavailable until Supabase is configured.');
  }

  return createBrowserClient(supabaseUrl, supabaseAnonKey);
}
