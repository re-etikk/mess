import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const subscriptionId = body.subscription_id;
    const additionalDays = body.additional_days || 30;
    const additionalCredits = body.additional_credits || 30;

    let sub = subscriptionId ? platformStore.subscriptions.get(subscriptionId) : null;
    if (!sub) {
      // Find latest active or expired subscription for customer
      const customerId = body.customer_id || 'cust-ritik-001';
      sub = Array.from(platformStore.subscriptions.values()).find((s) => s.customer_id === customerId);
    }

    if (!sub) {
      return NextResponse.json(
        { success: false, error: 'Subscription not found to renew.' },
        { status: 404 }
      );
    }

    sub.status = 'active';
    const currentExpiry = new Date(sub.expires_at).getTime() > Date.now() ? new Date(sub.expires_at) : new Date();
    sub.expires_at = new Date(currentExpiry.getTime() + additionalDays * 24 * 60 * 60 * 1000).toISOString();

    if (sub.plan_type === 'meal_credits') {
      sub.remaining_meal_credits = (sub.remaining_meal_credits ?? 0) + additionalCredits;
    }

    return NextResponse.json({
      success: true,
      subscription: sub,
      message: `Plan successfully renewed until ${new Date(sub.expires_at).toLocaleDateString('en-IN')}!`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Failed to renew subscription' },
      { status: 500 }
    );
  }
}
