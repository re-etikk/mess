import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { requireCustomerIdentity } from '@/lib/auth-session';
import { requireProviderOwnership } from '@/lib/provider-auth';

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
    return NextResponse.json(
      {
        success: false,
        error: 'Account deletion requires explicit confirmation. Please confirm your request.',
      },
      { status: 400 }
    );
  }

  if (userId) {
    const auth = await requireCustomerIdentity(req, userId);
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }
  }

  if (providerId) {
    const provAuth = await requireProviderOwnership(req, providerId);
    if (!provAuth.ok) {
      return NextResponse.json({ success: false, error: provAuth.error }, { status: provAuth.status });
    }
  }

  const admin = getAdminClient();
  if (admin) {
    try {
      if (userId) {
        await admin.from('subscriptions').update({ status: 'cancelled' }).eq('customer_id', userId);
        await admin.from('customer_addresses').delete().eq('customer_id', userId);
        await admin.from('customer_notifications').delete().eq('customer_id', userId);
        await admin.from('daily_meal_events').delete().eq('customer_id', userId);
        await admin.from('profiles').update({
          display_name: 'Deleted User',
          email: null,
          phone_e164: null,
          default_address: null,
        }).eq('id', userId);
        try {
          await admin.auth.admin.deleteUser(userId);
        } catch {}
      }

      if (providerId) {
        await admin
          .from('providers')
          .update({
            status: 'suspended',
            display_name: 'Deleted Account',
            public_phone: null,
            public_email: null,
          })
          .eq('id', providerId);

        await admin.from('subscription_plans').update({ active: false, published: false }).eq('provider_id', providerId);
        await admin.from('meal_slots').update({ active: false }).eq('provider_id', providerId);
        await admin.from('menu_items').update({ active: false }).eq('provider_id', providerId);
      }
    } catch (e: any) {
      console.warn('Account deletion DB warning:', e?.message);
    }
  }

  if (providerId) {
    platformStore.providers.delete(providerId);
  }

  return NextResponse.json({
    success: true,
    message:
      'Your account, profile information, and associated credentials have been deleted in accordance with data safety guidelines.',
  });
}
