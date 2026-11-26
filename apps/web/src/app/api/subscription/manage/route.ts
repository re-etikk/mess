import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { requireCustomerIdentity } from '@/lib/auth-session';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const customerIdParam = params.get('customer_id')?.trim();
  const subscriptionId = params.get('subscription_id')?.trim();

  if (!customerIdParam && !subscriptionId) {
    return NextResponse.json({ success: false, error: 'customer_id or subscription_id is required.' }, { status: 400 });
  }

  const auth = await requireCustomerIdentity(req, customerIdParam);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }
  const customerId = customerIdParam || auth.userId;

  const admin = getAdminClient();
  let rows: any[] = [];

  if (admin) {
    try {
      let query = admin
        .from('subscriptions')
        .select('*, providers:provider_id(id,display_name,locality,city,public_phone,address_line1,cover_path)')
        .order('created_at', { ascending: false });
      if (subscriptionId) query = query.eq('id', subscriptionId);
      if (!auth.isAdmin) {
        query = query.eq('customer_id', customerId);
      } else if (customerIdParam) {
        query = query.eq('customer_id', customerIdParam);
      }
      const { data } = await query.limit(40);
      rows = data ?? [];
    } catch (e: any) {
      console.warn('subscription/manage GET error:', e?.message);
    }
  }

  if (rows.length === 0 && platformStore.subscriptions.size > 0) {
    for (const s of platformStore.subscriptions.values()) {
      if (!auth.isAdmin && s.customer_id !== customerId) continue;
      if ((subscriptionId && s.id === subscriptionId) || (!subscriptionId && s.customer_id === customerId)) {
        const prov = platformStore.providers.get(s.provider_id);
        rows.push({
          ...s,
          plan_type_snapshot: s.plan_type,
          plan_name_snapshot: s.plan_name,
          providers: prov
            ? {
                id: prov.id,
                display_name: prov.display_name,
                locality: prov.locality,
                city: prov.city,
                public_phone: prov.phone,
              }
            : { id: s.provider_id, display_name: 'Mess Partner' },
        });
      }
    }
  }

  const formatted = rows.map((s) => {
    const prov = Array.isArray(s.providers) ? s.providers[0] : s.providers;
    const now = Date.now();
    const startsMs = s.starts_at ? new Date(s.starts_at).getTime() : now;
    const expiresMs = s.expires_at ? new Date(s.expires_at).getTime() : now;
    const totalDays = Math.max(1, Math.ceil((expiresMs - startsMs) / 86400000));
    const daysRemaining = Math.max(0, Math.ceil((expiresMs - now) / 86400000));

    return {
      ...s,
      provider_name: prov?.display_name || 'Mess Partner',
      provider_locality: prov?.locality || '',
      provider_city: prov?.city || '',
      provider_phone: prov?.public_phone || '',
      provider_address: prov?.address_line1 || '',
      total_days: totalDays,
      days_remaining: daysRemaining,
      price_inr: Math.round(Number(s.price_paid_paise || 0) / 100),
      skip_allowance: Number(s.skip_allowance ?? 2),
      skips_used: Number(s.skips_used ?? 0),
      repeat_days: Array.isArray(s.repeat_days) && s.repeat_days.length > 0 ? s.repeat_days : [1, 2, 3, 4, 5, 6, 7],
      auto_renewal: Boolean(s.auto_renewal),
      reminder_days_before: Number(s.reminder_days_before ?? 2),
      whatsapp_updates: Boolean(s.whatsapp_updates),
    };
  });

  // Never include unpaid `pending_payment` passes inside active_subscriptions
  const active = formatted.filter((s) => ['active', 'paused'].includes(s.status));
  const pending = formatted.filter((s) => s.status === 'pending_payment');
  const past = formatted.filter((s) => ['cancelled', 'expired', 'refunded', 'payment_failed'].includes(s.status));

  return NextResponse.json(
    {
      success: true,
      active_subscriptions: active,
      pending_subscriptions: pending,
      past_subscriptions: past,
      subscriptions: formatted,
    },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const action = String(body.action || '').trim();
  const subscriptionId = String(body.subscription_id || '').trim();
  const customerIdParam = String(body.customer_id || '').trim();

  if (!action || !subscriptionId) {
    return NextResponse.json({ success: false, error: 'action and subscription_id are required.' }, { status: 400 });
  }

  const auth = await requireCustomerIdentity(req, customerIdParam || undefined);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }

  const admin = getAdminClient();
  const now = new Date();

  const verifySubOwner = (sub: any) => auth.isAdmin || (sub && sub.customer_id === auth.userId);

  if (action === 'pause') {
    const startStr = String(body.pause_start_date || now.toISOString().slice(0, 10));
    const endStr = String(body.pause_end_date || '');
    if (!endStr) {
      return NextResponse.json({ success: false, error: 'pause_end_date is required.' }, { status: 400 });
    }
    const startDt = new Date(`${startStr}T00:00:00+05:30`);
    const endDt = new Date(`${endStr}T23:59:59+05:30`);
    const pauseDays = Math.min(30, Math.max(1, Math.round((endDt.getTime() - startDt.getTime()) / 86400000)));

    if (admin) {
      const { data: sub } = await admin.from('subscriptions').select('*').eq('id', subscriptionId).maybeSingle();
      if (!sub) return NextResponse.json({ success: false, error: 'Subscription not found.' }, { status: 404 });
      if (!verifySubOwner(sub)) {
        return NextResponse.json({ success: false, error: 'You cannot modify this subscription.' }, { status: 403 });
      }
      if (sub.status === 'paused') {
        return NextResponse.json({ success: false, error: 'Subscription is already paused.' }, { status: 400 });
      }
      if (sub.status !== 'active') {
        return NextResponse.json({ success: false, error: 'Only active subscriptions can be paused.' }, { status: 400 });
      }
      const alreadyPausedDays = Number(sub.paused_days_total || 0);
      if (alreadyPausedDays + pauseDays > 45) {
        return NextResponse.json({ success: false, error: 'Maximum pause allowance (45 days) reached for this cycle.' }, { status: 400 });
      }

      const prevExpiry = sub.expires_at ? new Date(sub.expires_at) : now;
      const newExpiry = new Date(prevExpiry.getTime() + pauseDays * 86400000);

      const { data: updated, error } = await admin
        .from('subscriptions')
        .update({
          status: 'paused',
          pause_started_at: startDt.toISOString(),
          pause_ends_at: endDt.toISOString(),
          paused_days_total: alreadyPausedDays + pauseDays,
          expires_at: newExpiry.toISOString(),
          updated_at: now.toISOString(),
        })
        .eq('id', subscriptionId)
        .select('*')
        .single();

      if (!error && updated) {
        return NextResponse.json({
          success: true,
          subscription: updated,
          pause_days: pauseDays,
          new_expires_at: newExpiry.toISOString(),
          message: `Subscription paused for ${pauseDays} days. Validity extended automatically.`,
        });
      }
    }

    const memSub = platformStore.subscriptions.get(subscriptionId) as any;
    if (memSub) {
      if (!verifySubOwner(memSub)) {
        return NextResponse.json({ success: false, error: 'You cannot modify this subscription.' }, { status: 403 });
      }
      if (memSub.status === 'paused') {
        return NextResponse.json({ success: false, error: 'Subscription is already paused.' }, { status: 400 });
      }
      memSub.status = 'paused';
      memSub.pause_started_at = startDt.toISOString();
      memSub.pause_ends_at = endDt.toISOString();
      memSub.paused_days_total = Number(memSub.paused_days_total || 0) + pauseDays;
      const prevExp = new Date(memSub.expires_at || now);
      memSub.expires_at = new Date(prevExp.getTime() + pauseDays * 86400000).toISOString();
      platformStore.subscriptions.set(subscriptionId, memSub);
      return NextResponse.json({ success: true, subscription: memSub, pause_days: pauseDays });
    }
    return NextResponse.json({ success: false, error: 'Subscription not found.' }, { status: 404 });
  }

  if (action === 'resume') {
    if (admin) {
      const { data: sub } = await admin.from('subscriptions').select('*').eq('id', subscriptionId).maybeSingle();
      if (!sub) return NextResponse.json({ success: false, error: 'Subscription not found.' }, { status: 404 });
      if (!verifySubOwner(sub)) return NextResponse.json({ success: false, error: 'Forbidden' }, { status: 403 });

      // Deduct unused future pause days when resuming early so pause->resume cannot mint extra days
      let nextExpiryIso = sub.expires_at;
      let nextTotalPaused = Number(sub.paused_days_total || 0);
      if (sub.status === 'paused' && sub.pause_ends_at && sub.expires_at) {
        const endMs = new Date(sub.pause_ends_at).getTime();
        if (endMs > now.getTime()) {
          const unusedDays = Math.floor((endMs - now.getTime()) / 86400000);
          if (unusedDays > 0) {
            nextExpiryIso = new Date(new Date(sub.expires_at).getTime() - unusedDays * 86400000).toISOString();
            nextTotalPaused = Math.max(0, nextTotalPaused - unusedDays);
          }
        }
      }

      const { data: updated, error } = await admin
        .from('subscriptions')
        .update({
          status: 'active',
          pause_started_at: null,
          pause_ends_at: null,
          paused_days_total: nextTotalPaused,
          expires_at: nextExpiryIso,
          updated_at: now.toISOString(),
        })
        .eq('id', subscriptionId)
        .select('*')
        .single();
      if (!error && updated) {
        return NextResponse.json({ success: true, subscription: updated, message: 'Subscription resumed.' });
      }
    }
    const memSub = platformStore.subscriptions.get(subscriptionId) as any;
    if (memSub) {
      if (!verifySubOwner(memSub)) return NextResponse.json({ success: false, error: 'Forbidden' }, { status: 403 });
      memSub.status = 'active';
      memSub.pause_started_at = null;
      memSub.pause_ends_at = null;
      platformStore.subscriptions.set(subscriptionId, memSub);
      return NextResponse.json({ success: true, subscription: memSub, message: 'Subscription resumed.' });
    }
    return NextResponse.json({ success: false, error: 'Subscription not found.' }, { status: 404 });
  }

  if (action === 'cancel') {
    const reason = String(body.reason || body.cancellation_reason || 'User cancelled').trim().slice(0, 300);
    if (admin) {
      const { data: sub } = await admin.from('subscriptions').select('id,customer_id').eq('id', subscriptionId).maybeSingle();
      if (!sub) return NextResponse.json({ success: false, error: 'Subscription not found.' }, { status: 404 });
      if (!verifySubOwner(sub)) return NextResponse.json({ success: false, error: 'Forbidden' }, { status: 403 });

      const { data: updated, error } = await admin
        .from('subscriptions')
        .update({
          status: 'cancelled',
          cancelled_at: now.toISOString(),
          cancellation_reason: reason,
          auto_renewal: false,
          updated_at: now.toISOString(),
        })
        .eq('id', subscriptionId)
        .select('*')
        .single();
      if (!error && updated) {
        return NextResponse.json({ success: true, subscription: updated, message: 'Subscription cancelled.' });
      }
    }
    const memSub = platformStore.subscriptions.get(subscriptionId) as any;
    if (memSub) {
      if (!verifySubOwner(memSub)) return NextResponse.json({ success: false, error: 'Forbidden' }, { status: 403 });
      memSub.status = 'cancelled';
      memSub.cancellation_reason = reason;
      platformStore.subscriptions.set(subscriptionId, memSub);
      return NextResponse.json({ success: true, subscription: memSub, message: 'Subscription cancelled.' });
    }
    return NextResponse.json({ success: false, error: 'Subscription not found.' }, { status: 404 });
  }

  if (action === 'update_preferences') {
    const updateData: any = { updated_at: now.toISOString() };
    if (Array.isArray(body.repeat_days)) {
      const cleaned = body.repeat_days.map((d: any) => Number(d)).filter((d: number) => d >= 1 && d <= 7);
      if (cleaned.length > 0) updateData.repeat_days = Array.from(new Set(cleaned));
    }
    if (typeof body.auto_renewal === 'boolean') updateData.auto_renewal = body.auto_renewal;
    if (body.reminder_days_before != null) {
      const rem = Number(body.reminder_days_before);
      if (isFinite(rem)) updateData.reminder_days_before = Math.min(14, Math.max(0, Math.round(rem)));
    }
    if (typeof body.whatsapp_updates === 'boolean') updateData.whatsapp_updates = body.whatsapp_updates;

    if (admin) {
      const { data: sub } = await admin.from('subscriptions').select('id,customer_id').eq('id', subscriptionId).maybeSingle();
      if (!sub) return NextResponse.json({ success: false, error: 'Subscription not found.' }, { status: 404 });
      if (!verifySubOwner(sub)) return NextResponse.json({ success: false, error: 'Forbidden' }, { status: 403 });

      const { data: updated, error } = await admin
        .from('subscriptions')
        .update(updateData)
        .eq('id', subscriptionId)
        .select('*')
        .single();
      if (!error && updated) {
        return NextResponse.json({ success: true, subscription: updated, message: 'Subscription preferences saved.' });
      }
    }
    const memSub = platformStore.subscriptions.get(subscriptionId) as any;
    if (memSub) {
      if (!verifySubOwner(memSub)) return NextResponse.json({ success: false, error: 'Forbidden' }, { status: 403 });
      Object.assign(memSub, updateData);
      return NextResponse.json({ success: true, subscription: memSub, message: 'Preferences updated.' });
    }
    return NextResponse.json({ success: false, error: 'Subscription not found.' }, { status: 404 });
  }

  return NextResponse.json({ success: false, error: 'Invalid subscription management action.' }, { status: 400 });
}
