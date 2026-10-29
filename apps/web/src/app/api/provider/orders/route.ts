import { NextRequest, NextResponse } from 'next/server';
import { platformStore, CounterOrderData } from '@/lib/platform-service';
import crypto from 'crypto';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';

  let orders = Array.from(platformStore.counterOrders.values()).filter(
    (o) => o.provider_id === providerId
  );

  orders.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

  const totalRevenue = orders.reduce((sum, o) => sum + o.total_amount_inr, 0);

  return NextResponse.json({
    success: true,
    total_orders: orders.length,
    total_revenue_inr: totalRevenue,
    orders,
  });
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = body.provider_id || 'prov-radhe-001';
    const customerName = body.customer_name?.trim() || 'Walk-in Customer';
    const customerPhone = body.customer_phone?.trim() || '';
    const items = Array.isArray(body.items) ? body.items : [];
    const paymentMode = body.payment_mode || 'cash';
    const totalAmountInr = Number(body.total_amount_inr) || items.reduce((sum: number, i: any) => sum + (Number(i.price || 0) * (Number(i.quantity) || 1)), 0);

    if (totalAmountInr <= 0) {
      return NextResponse.json({ success: false, error: 'Total amount must be greater than zero.' }, { status: 400 });
    }

    const itemsSummary = items.map((i: any) => `${i.name} (x${i.quantity || 1})`).join(', ') || 'Direct Counter Order';
    const orderId = `ord-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;

    const order: CounterOrderData = {
      id: orderId,
      provider_id: providerId,
      customer_name: customerName,
      customer_phone: customerPhone,
      items_summary: itemsSummary,
      items,
      total_amount_inr: totalAmountInr,
      payment_mode: paymentMode,
      status: 'paid',
      created_at: new Date().toISOString(),
    };

    platformStore.counterOrders.set(orderId, order);

    return NextResponse.json({
      success: true,
      order,
      message: `✅ Order of ₹${totalAmountInr} recorded successfully!`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Failed to record counter order.' },
      { status: 500 }
    );
  }
}
