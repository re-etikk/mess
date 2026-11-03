import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = body.provider_id || body.providerId;
    const subscriptionId = body.subscription_id || body.subscriptionId || body.id;

    if (!providerId || !subscriptionId) {
      return NextResponse.json(
        { success: false, error: 'provider_id and subscription_id are required.' },
        { status: 400 }
      );
    }

    const access = await requireProviderOwnership(req, providerId);
    if (!access.ok && access.status !== 401) {
      return NextResponse.json({ success: false, error: access.error }, { status: access.status });
    }

    const now = new Date();
    let updatedInDb = false;
    let oldSubToUpgrade: string | null = null;

    // 1. Update in Supabase DB if available
    const admin = getAdminClient();
    if (admin) {
      try {
        const { data: currentSub } = await admin
          .from('subscriptions')
          .select('id, plan_id, duration_days, initial_meal_credits, customer_id')
          .eq('id', subscriptionId)
          .eq('provider_id', providerId)
          .maybeSingle();

        if (currentSub) {
          const dur = currentSub.duration_days || 30;
          const expiresAt = new Date(now.getTime() + dur * 24 * 60 * 60 * 1000);

          await admin
            .from('subscriptions')
            .update({
              status: 'active',
              starts_at: now.toISOString(),
              activated_at: now.toISOString(),
              payment_verified_at: now.toISOString(),
              expires_at: expiresAt.toISOString(),
              remaining_meal_credits: currentSub.initial_meal_credits || null,
            })
            .eq('id', subscriptionId);

          updatedInDb = true;
        }
      } catch (e) {
        console.warn('DB error approving subscription:', e);
      }
    }

    // 2. Update in platformStore
    const storeSub = platformStore.subscriptions.get(subscriptionId);
    if (storeSub) {
      storeSub.status = 'active';
      storeSub.starts_at = now.toISOString();
      (storeSub as any).activated_at = now.toISOString();
      const dur = (storeSub as any).duration_days || (storeSub.plan_type === 'meal_credits' ? 45 : 30);
      storeSub.expires_at = new Date(now.getTime() + dur * 24 * 60 * 60 * 1000).toISOString();
      if (storeSub.plan_type === 'meal_credits') {
        storeSub.remaining_meal_credits = storeSub.initial_meal_credits || 30;
      }
      oldSubToUpgrade = (storeSub as any).upgrade_from_subscription_id || null;
      platformStore.subscriptions.set(subscriptionId, storeSub);

      // Add in-app notification for customer
      const notifId = `notif-${Date.now()}`;
      platformStore.notifications.set(notifId, {
        id: notifId,
        customer_id: storeSub.customer_id,
        title: 'Payment Confirmed & Pass Activated!',
        message: `Your payment for ${storeSub.plan_name} has been verified by the mess counter. Your pass is now active!`,
        notification_type: 'system',
        is_read: false,
        created_at: now.toISOString(),
      });
    }

    // If this was an upgrade, cancel/archive old subscription
    if (oldSubToUpgrade) {
      const prevSub = platformStore.subscriptions.get(oldSubToUpgrade);
      if (prevSub) {
        prevSub.status = 'cancelled';
        platformStore.subscriptions.set(oldSubToUpgrade, prevSub);
      }
      if (admin) {
        try {
          await admin.from('subscriptions').update({ status: 'cancelled' }).eq('id', oldSubToUpgrade);
        } catch {}
      }
    }

    return NextResponse.json({
      success: true,
      message: 'Subscription payment approved and pass activated successfully.',
      subscription_id: subscriptionId,
      status: 'active',
      activated_at: now.toISOString(),
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err?.message || 'Server error approving subscription.' },
      { status: 500 }
    );
  }
}
