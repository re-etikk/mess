import { NextRequest } from 'next/server';
import { handleCashfreeWebhook } from '@/app/api/payments/cashfree/webhook/route';

export const dynamic = 'force-dynamic';

/** Compatibility webhook endpoint routed to Cashfree signature verification & fulfillment. */
export async function POST(req: NextRequest) {
  return handleCashfreeWebhook(req);
}
