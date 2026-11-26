import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const providerId = String(body.provider_id || body.providerId || '').trim();
  const subscriptionId = String(body.subscription_id || body.subscriptionId || '').trim();
  const action = String(body.action || 'renew').trim().toLowerCase();
  const addDaysCount = Math.min(365, Math.max(1, Number(body.days) || 30));
  const addCreditsCount = Math.min(1000, Math.max(1, Number(body.credits) || 30));

  if (!providerId || !subscriptionId) {
    return NextResponse.json({ success: false, error: 'provider_id and subscription_id are required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const now = new Date();
  const admin = getAdminClient();

  if (admin) {
    const { data: sub, error } = await admin
      .from('subscriptions')
      .select('id,customer_id,provider_id,plan_type_snapshot,plan_name_snapshot,status,expires_at,remaining_meal_credits,initial_meal_credits')
      .eq('id', subscriptionId)
      .eq('provider_id', providerId)
      .maybeSingle();

    if (error || !sub) {
      return NextResponse.json({ success: false, error: 'Subscriber pass not found for this kitchen.' }, { status: 404 });
    }

    if (action === 'suspend' || action === 'pause') {
      await admin
        .from('subscriptions')
        .update({ status: 'paused', pause_started_at: now.toISOString(), updated_at: now.toISOString() })
        .eq('id', subscriptionId)
        .eq('provider_id', providerId);

      return NextResponse.json({ success: true, status: 'paused', message: 'Subscriber pass paused.' });
    }

    const baseDate = sub.expires_at && new Date(sub.expires_at).getTime() > now.getTime() ? new Date(sub.expires_at) : now;
    const nextExpires = new Date(baseDate.getTime() + addDaysCount * 24 * 60 * 60 * 1000);
    const nextCredits =
      sub.plan_type_snapshot === 'meal_credits'
        ? Number(sub.remaining_meal_credits || 0) + addCreditsCount
        : sub.remaining_meal_credits;

    const { data: updated, error: upErr } = await admin
      .from('subscriptions')
      .update({
        status: 'active',
        expires_at: nextExpires.toISOString(),
        remaining_meal_credits: nextCredits,
        activated_at: now.toISOString(),
        updated_at: now.toISOString(),
      })
      .eq('id', subscriptionId)
      .eq('provider_id', providerId)
      .select('*')
      .single();

    if (upErr) {
      return NextResponse.json({ success: false, error: upErr.message || 'Could not update pass.' }, { status: 500 });
    }

    await admin
      .from('customer_notifications')
      .insert({
        customer_id: sub.customer_id,
        title: 'Pass Renewed by Kitchen',
        message: `${sub.plan_name_snapshot || 'Your meal pass'} has been renewed (+${addDaysCount} days).`,
        notification_type: 'system',
        action_route: '/plans',
      })
      .then(() => null, () => null);

    return NextResponse.json({ success: true, subscription: updated, message: 'Subscriber pass reactivated.' });
  }

  const memSub = platformStore.subscriptions.get(subscriptionId);
  if (!memSub || memSub.provider_id !== providerId) {
    return NextResponse.json({ success: false, error: 'Subscriber pass not found.' }, { status: 404 });
  }
  const baseMs = memSub.expires_at && new Date(memSub.expires_at).getTime() > now.getTime() ? new Date(memSub.expires_at).getTime() : now.getTime();
  memSub.status = action === 'suspend' || action === 'pause' ? ('paused' as any) : 'active';
  if (memSub.status === 'active') {
    memSub.expires_at = new Date(baseMs + addDaysCount * 24 * 60 * 60 * 1000).toISOString();
    if (memSub.plan_type === 'meal_credits') {
      memSub.remaining_meal_credits = (memSub.remaining_meal_credits || 0) + addCreditsCount;
    }
  }
  platformStore.subscriptions.set(subscriptionId, memSub);
  return NextResponse.json({ success: true, subscription: memSub, message: 'Subscriber pass updated.' });
}
