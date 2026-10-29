-- Fix Supabase Service Role Permissions for Table Access
-- Ensures backend Next.js API routes with SUPABASE_SERVICE_ROLE_KEY can manage providers, profiles, subscriptions, redemptions, and plans

GRANT USAGE ON SCHEMA public TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO service_role;

-- Ensure authenticated and anon can read active providers for public search
GRANT SELECT ON public.providers TO anon, authenticated;
GRANT SELECT ON public.subscription_plans TO anon, authenticated;
GRANT SELECT ON public.menus TO anon, authenticated;
GRANT SELECT ON public.meal_slots TO anon, authenticated;
GRANT SELECT ON public.menu_items TO anon, authenticated;
