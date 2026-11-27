import { getAdminClient } from './supabase/admin';
import { platformStore } from './platform-service';
import { addPartnerNotification } from './partner-notifications';
import { sendCustomerInvoiceEmail } from './notifications';
import { cashfreeOrderStore, type PendingCashfreeOrderMeta } from './cashfree';
import { recordPromoRedemption } from './promo-engine';

export interface FulfillCashfreeOrderInput {
  orderId: string;
  cfOrderId?: string;
  cfPaymentId?: string;
  orderAmountInr?: number;
  orderTags?: Record<string, string>;
}

export interface FulfillCashfreeOrderResult {
  alreadyProcessed: boolean;
  purpose: string;
  subscription?: Record<string, unknown> | null;
  orderId: string;
  amountInr: number;
}

export async function fulfillCashfreePaidOrder(
  input: FulfillCashfreeOrderInput,
): Promise<FulfillCashfreeOrderResult> {
  const admin = getAdminClient();
  const now = new Date();
  const meta: PendingCashfreeOrderMeta | undefined = cashfreeOrderStore.get(input.orderId);
  const tags = input.orderTags || {};

  // Check DB payment_transactions for idempotency & metadata fallback
  let dbTx: any = null;
  if (admin) {
    try {
      const { data } = await admin
        .from('payment_transactions')
        .select('*')
        .eq('gateway_name', 'cashfree')
        .eq('gateway_order_id', input.orderId)
        .maybeSingle();
      dbTx = data;
    } catch (err) {
      console.warn('Error checking payment_transactions:', err);
    }
  }

  if (dbTx?.status === 'succeeded' || meta?.status === 'paid') {
    const existingSubId = meta?.subscription_id || dbTx?.subscription_id || tags.sub_id;
    let existingSub: any = existingSubId ? platformStore.subscriptions.get(existingSubId) : null;
    if (!existingSub && admin && existingSubId) {
      try {
        const { data } = await admin.from('subscriptions').select('*').eq('id', existingSubId).maybeSingle();
        if (data) existingSub = data;
      } catch {}
    }
    return {
      alreadyProcessed: true,
      purpose: meta?.purpose || tags.purpose || dbTx?.purpose || 'subscription_purchase',
      subscription: existingSub || null,
      orderId: input.orderId,
      amountInr: input.orderAmountInr ?? (dbTx ? Number(dbTx.amount_paise) / 100 : (meta ? meta.amount_paise / 100 : 0)),
    };
  }

  const purpose = meta?.purpose || tags.purpose || dbTx?.purpose || 'subscription_purchase';
  const subscriptionId = meta?.subscription_id || dbTx?.subscription_id || tags.sub_id;
  const providerId = meta?.provider_id || tags.prov_id || '';
  const customerId = meta?.customer_id || dbTx?.customer_id || tags.cust_id || '';
  const upgradeFromId = meta?.upgrade_from_subscription_id || tags.upgrade_from || '';
  const durationDays = meta?.duration_days || Number(tags.duration_days || 30) || 30;
  const amountPaise = dbTx?.amount_paise
    ? Number(dbTx.amount_paise)
    : (meta?.amount_paise ?? Math.round((input.orderAmountInr || 0) * 100));
  const amountInr = input.orderAmountInr ?? (amountPaise / 100);

  // Guard against underpayment if expected amount is known
  if (input.orderAmountInr != null && amountPaise > 0) {
    const paidPaise = Math.round(input.orderAmountInr * 100);
    if (paidPaise < amountPaise) {
      throw new Error(`Paid amount ₹${input.orderAmountInr} is less than expected ₹${amountPaise / 100}.`);
    }
  }

  // Update payment_transactions in DB
  if (admin && dbTx?.id) {
    try {
      await admin
        .from('payment_transactions')
        .update({
          status: 'succeeded',
          gateway_payment_id: input.cfPaymentId || dbTx.gateway_payment_id || input.orderId,
          verified_at: now.toISOString(),
          sanitized_gateway_metadata: {
            ...(dbTx.sanitized_gateway_metadata || {}),
            cf_order_id: input.cfOrderId || null,
            cf_payment_id: input.cfPaymentId || null,
            verified_via: 'cashfree_pg',
          },
        })
        .eq('id', dbTx.id);
    } catch (err) {
      console.warn('Error updating payment_transactions:', err);
    }
  }

  let activatedSub: any = null;

  if (subscriptionId && (purpose === 'subscription_purchase' || purpose === 'plan_upgrade')) {
    const expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);

    // 1. Activate in Supabase DB
    if (admin) {
      try {
        const { data: currentSub } = await admin
          .from('subscriptions')
          .select('id, initial_meal_credits, starts_at')
          .eq('id', subscriptionId)
          .maybeSingle();

        if (currentSub) {
          const requestedStart = currentSub.starts_at ? new Date(currentSub.starts_at) : now;
          const effectiveStart = requestedStart.getTime() > now.getTime() ? requestedStart : now;
          const effectiveExpires = new Date(effectiveStart.getTime() + durationDays * 24 * 60 * 60 * 1000);
          const { data: updated } = await admin
            .from('subscriptions')
            .update({
              status: 'active',
              starts_at: effectiveStart.toISOString(),
              activated_at: now.toISOString(),
              payment_verified_at: now.toISOString(),
              expires_at: effectiveExpires.toISOString(),
              remaining_meal_credits: currentSub.initial_meal_credits ?? meta?.meal_credits ?? null,
            })
            .eq('id', subscriptionId)
            .select('*')
            .single();
          if (updated) activatedSub = updated;
        }
      } catch (err) {
        console.warn('DB error activating Cashfree subscription:', err);
      }
    }

    // 2. Activate in platformStore
    const storeSub = platformStore.subscriptions.get(subscriptionId);
    if (storeSub) {
      const requestedStart = storeSub.starts_at ? new Date(storeSub.starts_at) : now;
      const effectiveStart = requestedStart.getTime() > now.getTime() ? requestedStart : now;
      const effectiveExpires = new Date(effectiveStart.getTime() + durationDays * 24 * 60 * 60 * 1000);
      storeSub.status = 'active';
      storeSub.starts_at = effectiveStart.toISOString();
      (storeSub as any).activated_at = now.toISOString();
      storeSub.expires_at = effectiveExpires.toISOString();
      storeSub.payment_mode = 'online';
      (storeSub as any).cashfree_order_id = input.orderId;
      (storeSub as any).cashfree_payment_id = input.cfPaymentId || '';
      if (storeSub.plan_type === 'meal_credits') {
        storeSub.remaining_meal_credits = storeSub.initial_meal_credits || meta?.meal_credits || 30;
      }
      platformStore.subscriptions.set(subscriptionId, storeSub);
      if (!activatedSub) activatedSub = storeSub;
    }

    // 3. Cancel previous subscription if this was an upgrade
    if (upgradeFromId) {
      const prevStoreSub = platformStore.subscriptions.get(upgradeFromId);
      if (prevStoreSub) {
        prevStoreSub.status = 'cancelled';
        platformStore.subscriptions.set(upgradeFromId, prevStoreSub);
      }
      if (admin) {
        try {
          await admin.from('subscriptions').update({ status: 'cancelled' }).eq('id', upgradeFromId);
        } catch {}
      }
    }

    const usedPromo = String(activatedSub?.promo_code || '').trim();
    const promoDisc = Number(activatedSub?.discount_paise || 0);
    if (usedPromo && promoDisc > 0 && customerId) {
      await recordPromoRedemption({
        admin,
        code: usedPromo,
        customerId,
        providerId,
        subscriptionId,
        discountPaise: promoDisc,
      });
    }
  }

  // Mark local store paid
  if (meta) {
    meta.status = 'paid';
    meta.verified_at = now.toISOString();
    cashfreeOrderStore.set(input.orderId, meta);
  }

  // Notifications
  const customerName = meta?.customer_name || tags.cust_name || 'Customer';
  const planName = meta?.plan_name || tags.plan_name || 'Meal Pass';

  if (providerId) {
    addPartnerNotification({
      provider_id: providerId,
      type: purpose === 'plan_upgrade' ? 'plan_upgrade' : 'info',
      title: purpose === 'plan_upgrade' ? 'Plan Upgrade Paid Online (Cashfree)' : 'Online Payment Received (Cashfree)',
      message: `${customerName} paid ₹${amountInr.toFixed(0)} online for ${planName}. Pass is automatically active!`,
      customer_name: customerName,
      customer_phone: meta?.customer_phone || '',
      amount_inr: amountInr,
      subscription_id: subscriptionId,
    });
  }

  if (customerId) {
    const notifId = `notif-cf-${Date.now()}`;
    const notifMsg = `₹${amountInr.toFixed(0)} received via Cashfree for ${planName}. Your meal pass is active right away!`;
    platformStore.notifications.set(notifId, {
      id: notifId,
      customer_id: customerId,
      title: 'Online Payment Successful',
      message: notifMsg,
      notification_type: 'system',
      is_read: false,
      created_at: now.toISOString(),
    });
    if (admin) {
      try {
        await admin.from('customer_notifications').insert({
          customer_id: customerId,
          title: 'Online Payment Successful',
          message: notifMsg,
          notification_type: 'payment',
        });
      } catch {}
    }
  }

  let recipientEmail = (meta as any)?.customer_email || tags.cust_email || '';
  if (!recipientEmail && admin && customerId) {
    try {
      const { data: prof } = await admin.from('profiles').select('email').eq('id', customerId).maybeSingle();
      if (prof?.email) recipientEmail = prof.email;
      if (!recipientEmail) {
        const { data: authU } = await admin.auth.admin.getUserById(customerId);
        if (authU?.user?.email) recipientEmail = authU.user.email;
      }
    } catch {}
  }

  if (recipientEmail && recipientEmail.includes('@')) {
    let resolvedProviderName = (meta as any)?.provider_name || 'Thali Mess Kitchen';
    if (admin && providerId) {
      try {
        const { data: provRow } = await admin.from('providers').select('display_name').eq('id', providerId).maybeSingle();
        if (provRow?.display_name) resolvedProviderName = provRow.display_name;
      } catch {}
    }
    await sendCustomerInvoiceEmail({
      to: recipientEmail,
      customerName,
      providerName: resolvedProviderName,
      planName,
      subscriptionId: subscriptionId || input.orderId,
      amountInr,
      paymentMode: 'cashfree_online',
      paymentStatus: 'Paid & Active',
      startsAtIso: now.toISOString(),
      expiresAtIso: (activatedSub?.expires_at as string) || new Date(now.getTime() + 30 * 86400000).toISOString(),
      transactionRef: input.cfPaymentId || input.orderId,
    }).catch(() => null);
  }

  return {
    alreadyProcessed: false,
    purpose,
    subscription: activatedSub,
    orderId: input.orderId,
    amountInr,
  };
}
