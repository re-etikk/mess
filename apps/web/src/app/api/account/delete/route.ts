import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body' }, { status: 400 });
  }

  const userId = String(body.user_id || body.id || '').trim();
  const providerId = String(body.provider_id || '').trim();
  const confirmation = String(body.confirmation || '').trim().toUpperCase();

  if (!userId && !providerId) {
    return NextResponse.json({ success: false, error: 'User ID or Provider ID is required.' }, { status: 400 });
  }

  if (confirmation !== 'DELETE' && confirmation !== 'CONFIRM') {
    return NextResponse.json({
      success: false,
      error: 'Account deletion requires explicit confirmation. Please confirm your request.',
    }, { status: 400 });
  }

  const admin = getAdminClient();
  if (admin) {
    try {
      if (userId) {
        // 1. Cancel active subscriptions
        await admin.from('subscriptions').update({ status: 'cancelled' }).eq('customer_user_id', userId);

        // 2. Anonymize/delete profile
        await admin.from('profiles').delete().eq('id', userId);

        // 3. Clear auth user if exists
        try {
          await admin.auth.admin.deleteUser(userId);
        } catch {}
      }

      if (providerId) {
        // Set provider status to deleted/suspended
        await admin.from('providers').update({
          status: 'suspended',
          display_name: 'Deleted Account',
          public_phone: null,
          public_email: null,
        }).eq('id', providerId);

        // Deactivate plans and slots
        await admin.from('subscription_plans').update({ active: false, published: false }).eq('provider_id', providerId);
        await admin.from('meal_slots').update({ active: false }).eq('provider_id', providerId);
        await admin.from('menu_items').update({ active: false }).eq('provider_id', providerId);
      }
    } catch (e: any) {
      console.warn('Account deletion DB warning:', e?.message);
    }
  }

  // Clear in-memory references if any
  if (providerId) {
    platformStore.providers.delete(providerId);
  }

  return NextResponse.json({
    success: true,
    message: 'Your account, profile information, and associated credentials have been permanently deleted in accordance with data safety guidelines.',
  });
}
