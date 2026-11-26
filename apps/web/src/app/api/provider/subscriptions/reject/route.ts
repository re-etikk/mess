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
    const reason = body.reason || 'Payment could not be verified by counter cashier.';

    if (!providerId || !subscriptionId) {
      return NextResponse.json(
        { success: false, error: 'provider_id and subscription_id are required.' },
        { status: 400 }
      );
    }

    const access = await requireProviderOwnership(req, providerId);
    if (!access.ok) {
      return NextResponse.json({ success: false, error: access.error }, { status: access.status });
    }

    const admin = getAdminClient();
    let dbCustomerId = '';
    let dbPlanName = 'Meal Pass';
    if (admin) {
      try {
        const { data: subRow } = await admin
          .from('subscriptions')
          .select('id,status,customer_id,plan_name_snapshot')
          .eq('id', subscriptionId)
          .eq('provider_id', providerId)
          .maybeSingle();
        if (subRow && subRow.status !== 'pending_payment') {
          return NextResponse.json(
            { success: false, error: `Only pending payment requests can be declined (current: ${subRow.status}).` },
            { status: 400 }
          );
        }
        if (subRow) {
          dbCustomerId = subRow.customer_id || '';
          dbPlanName = subRow.plan_name_snapshot || dbPlanName;
          await admin
            .from('subscriptions')
            .update({
              status: 'cancelled',
            })
            .eq('id', subscriptionId)
            .eq('provider_id', providerId)
            .eq('status', 'pending_payment');

          if (dbCustomerId) {
            await admin
              .from('customer_notifications')
              .insert({
                customer_id: dbCustomerId,
                title: 'Payment Request Declined',
                message: `Your payment request for ${dbPlanName} was declined: ${reason}`,
                notification_type: 'system',
                action_route: '/plans',
              })
              .then(() => null, () => null);
          }
        }
      } catch (e) {
        console.warn('DB error rejecting subscription:', e);
      }
    }

    const storeSub = platformStore.subscriptions.get(subscriptionId);
    if (storeSub) {
      storeSub.status = 'cancelled';
      platformStore.subscriptions.set(subscriptionId, storeSub);

      const notifId = `notif-${Date.now()}`;
      platformStore.notifications.set(notifId, {
        id: notifId,
        customer_id: storeSub.customer_id,
        title: 'Payment Request Declined',
        message: `Your payment request for ${storeSub.plan_name} was declined: ${reason}`,
        notification_type: 'system',
        is_read: false,
        created_at: new Date().toISOString(),
      });
    }

    return NextResponse.json({
      success: true,
      message: 'Subscription payment rejected.',
      subscription_id: subscriptionId,
      status: 'cancelled',
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err?.message || 'Server error rejecting subscription.' },
      { status: 500 }
    );
  }
}
