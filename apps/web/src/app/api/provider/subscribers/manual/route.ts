import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import crypto from 'crypto';
import {
  platformStore,
  SubscriptionData,
} from '@/lib/platform-service';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

const ManualSubscriberSchema = z.object({
  provider_id: z.string().min(1),
  customer_name: z.string().trim().min(2).max(100),
  customer_phone: z.string().trim().regex(/^\+?[0-9 ()-]{7,20}$/),
  customer_email: z.string().trim().email().optional().or(z.literal('')),
  plan_id: z.string().optional(),
  payment_mode: z.enum(['cash', 'counter_upi', 'complimentary', 'online']).default('cash'),
  amount_paid_inr: z.number().nonnegative().optional(),
  custom_days: z.number().int().positive().optional(),
  custom_credits: z.number().int().positive().optional(),
  notes: z.string().max(500).optional(),
});

export async function POST(req: NextRequest) {
  try {
    let payload: unknown;
    try {
      payload = await req.json();
    } catch {
      return NextResponse.json({ success: false, error: 'Invalid JSON request body.' }, { status: 400 });
    }

    const parsed = ManualSubscriberSchema.safeParse(payload);
    if (!parsed.success) {
      return NextResponse.json(
        { success: false, error: 'Invalid input.', details: parsed.error.flatten() },
        { status: 400 }
      );
    }

    const {
      provider_id,
      customer_name,
      customer_phone,
      customer_email,
      plan_id,
      payment_mode,
      amount_paid_inr,
      custom_days,
      custom_credits,
      notes,
    } = parsed.data;

    const cleanPhone = customer_phone.replace(/\D/g, '').slice(-10);
    if (cleanPhone.length < 10) {
      return NextResponse.json(
        { success: false, error: 'Please enter a valid 10-digit mobile number.' },
        { status: 400 }
      );
    }

    // 1. Ensure provider exists in memory
    let provider = platformStore.providers.get(provider_id);

    // 2. Select Plan
    let plan = plan_id ? platformStore.plans.get(plan_id) : null;
    if (!plan) {
      // Find any active plan for this provider
      const providerPlans = Array.from(platformStore.plans.values()).filter(
        (p) => p.provider_id === provider_id && p.is_active
      );
      if (providerPlans.length > 0) {
        plan = providerPlans[0];
      }
    }

    if (!plan) {
      return NextResponse.json(
        { success: false, error: 'No active subscription plan found. Please publish a plan in Plans & Pricing first.' },
        { status: 400 }
      );
    }

    const planType = plan?.plan_type || 'fixed_period';
    const planName = plan?.name || (planType === 'fixed_period' ? 'Monthly Unlimited' : 'Flexi Tracker Pack');
    const durationDays = custom_days || plan?.duration_days || (planType === 'fixed_period' ? 30 : 60);
    const mealCredits =
      planType === 'meal_credits'
        ? (custom_credits ?? plan?.meal_credits ?? 60)
        : null;

    const pricePaise = amount_paid_inr !== undefined
      ? Math.round(amount_paid_inr * 100)
      : (plan?.price_paise ?? (planType === 'fixed_period' ? 300000 : 240000));

    // 3. Resolve Customer ID
    let customerUserId = `cust-${cleanPhone}`;
    const effectiveEmail = customer_email?.trim() || `student-${cleanPhone}@thali.mess`;

    // Persist or register student in Supabase Auth if accessible
    try {
      const admin = getAdminClient();
      if (admin) {
        const { data: newUser } = await admin.auth.admin.createUser({
          email: effectiveEmail,
          password: `Student@${cleanPhone.slice(-4)}`,
          email_confirm: true,
          user_metadata: {
            display_name: customer_name,
            phone: cleanPhone,
            role: 'customer',
          },
        }).catch(() => ({ data: null }));

        if (newUser?.user?.id) {
          customerUserId = newUser.user.id;
        } else {
          // If already exists, lookup user
          const { data: listData } = await admin.auth.admin.listUsers({ perPage: 100 }).catch(() => ({ data: null }));
          const existing = listData?.users.find((u) => u.phone === cleanPhone || u.email === effectiveEmail || u.user_metadata?.phone === cleanPhone);
          if (existing?.id) customerUserId = existing.id;
        }
      }
    } catch (authEx) {
      console.warn('Student auth sync note:', authEx);
    }

    // 4. Create Active Subscription Record
    const subId = `sub-offline-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
    const newSub: SubscriptionData = {
      id: subId,
      customer_id: customerUserId,
      customer_name,
      customer_phone: cleanPhone,
      customer_email: effectiveEmail,
      provider_id,
      plan_id: plan?.id || 'plan-custom',
      plan_type: planType,
      plan_name: planName,
      status: 'active',
      starts_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString(),
      remaining_meal_credits: mealCredits,
      initial_meal_credits: mealCredits,
      price_paid_paise: pricePaise,
      payment_mode,
      created_at: new Date().toISOString(),
    };

    platformStore.subscriptions.set(subId, newSub);

    // Also attempt writing to public.subscriptions table if accessible
    try {
      const admin = getAdminClient();
      if (admin) {
        await admin.from('subscriptions').insert({
          id: subId,
          customer_id: customerUserId,
          provider_id,
          plan_id: plan?.id,
          status: 'active',
          starts_at: newSub.starts_at,
          expires_at: newSub.expires_at,
          remaining_meal_credits: mealCredits,
          price_paid_paise: pricePaise,
        });
      }
    } catch {}

    const passUrl = `https://mess-beta.vercel.app/customer/dashboard?phone=${cleanPhone}`;
    const whatsappText = `Namaste ${customer_name}! Aapka meal subscription "${planName}" activate ho gaya hai at ${provider?.display_name || 'Mess'}.\n\n• Validity: ${new Date(newSub.expires_at).toLocaleDateString('en-IN')}\n• Credits: ${mealCredits !== null ? mealCredits : 'Unlimited Meals'}\n• Payment Mode: ${payment_mode.toUpperCase()}\n\nApna digital meal pass dekhne ke liye click karein: ${passUrl}`;
    const whatsappUrl = `https://wa.me/91${cleanPhone}?text=${encodeURIComponent(whatsappText)}`;

    return NextResponse.json({
      success: true,
      subscription: newSub,
      pass_url: passUrl,
      whatsapp_url: whatsappUrl,
      message: `✅ Member ${customer_name} added successfully! Subscription is active.`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err?.message || 'Failed to add member subscription.' },
      { status: 500 }
    );
  }
}
