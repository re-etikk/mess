import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { platformStore } from '@/lib/platform-service';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

const ReactivateSchema = z.object({
  provider_id: z.string().min(1),
  subscription_id: z.string().min(1),
  action: z.enum(['extend_days', 'add_credits', 'renew']).default('renew'),
  days: z.number().int().positive().optional().default(30),
  credits: z.number().int().positive().optional().default(30),
  payment_mode: z.enum(['cash', 'counter_upi', 'complimentary']).default('cash'),
});

export async function POST(req: NextRequest) {
  try {
    let payload: unknown;
    try {
      payload = await req.json();
    } catch {
      return NextResponse.json({ success: false, error: 'Invalid JSON request body.' }, { status: 400 });
    }

    const parsed = ReactivateSchema.safeParse(payload);
    if (!parsed.success) {
      return NextResponse.json(
        { success: false, error: 'Invalid input.', details: parsed.error.flatten() },
        { status: 400 }
      );
    }

    const { provider_id, subscription_id, action, days, credits, payment_mode } = parsed.data;

    const sub = platformStore.subscriptions.get(subscription_id);
    if (!sub) {
      return NextResponse.json(
        { success: false, error: 'Subscription not found.' },
        { status: 404 }
      );
    }

    if (sub.provider_id !== provider_id) {
      return NextResponse.json(
        { success: false, error: 'You do not have permission to modify this subscription.' },
        { status: 403 }
      );
    }

    // Reactivate and update values
    sub.status = 'active';
    sub.payment_mode = payment_mode;

    const now = Date.now();
    const currentExpiryMs = new Date(sub.expires_at).getTime();
    const baseDateMs = currentExpiryMs > now ? currentExpiryMs : now;

    if (action === 'extend_days' || action === 'renew') {
      sub.expires_at = new Date(baseDateMs + days * 24 * 60 * 60 * 1000).toISOString();
    }

    if (action === 'add_credits' || action === 'renew') {
      if (sub.plan_type === 'meal_credits') {
        sub.remaining_meal_credits = (sub.remaining_meal_credits ?? 0) + credits;
      }
    }

    // Persist to Supabase table if available
    try {
      const admin = getAdminClient();
      if (admin) {
        await admin
          .from('subscriptions')
          .update({
            status: 'active',
            expires_at: sub.expires_at,
            remaining_meal_credits: sub.remaining_meal_credits,
          })
          .eq('id', sub.id);
      }
    } catch {}

    const cleanPhone = sub.customer_phone || '';
    const passUrl = `https://mess-beta.vercel.app/customer/dashboard?phone=${cleanPhone}`;
    const whatsappText = `Namaste ${sub.customer_name || 'Student'}! Aapka meal subscription successfully renew / reactivate ho gaya hai.\n\n• New Expiry: ${new Date(sub.expires_at).toLocaleDateString('en-IN')}\n• Credits: ${sub.remaining_meal_credits ?? 'Unlimited Meals'}\n\nApna pass check karein: ${passUrl}`;
    const whatsappUrl = cleanPhone ? `https://wa.me/91${cleanPhone}?text=${encodeURIComponent(whatsappText)}` : '';

    return NextResponse.json({
      success: true,
      subscription: sub,
      pass_url: passUrl,
      whatsapp_url: whatsappUrl,
      message: `✅ Subscription successfully reactivated until ${new Date(sub.expires_at).toLocaleDateString('en-IN')}!`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err?.message || 'Failed to reactivate subscription.' },
      { status: 500 }
    );
  }
}
