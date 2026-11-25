import { NextRequest } from 'next/server';
import { handleCashfreeWebhook } from '@/lib/cashfree-webhook-handler';

export const dynamic = 'force-dynamic';

/** Compatibility webhook endpoint routed to Cashfree signature verification & fulfillment. */
export async function POST(req: NextRequest) {
  return handleCashfreeWebhook(req);
}
