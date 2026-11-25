import { NextRequest } from 'next/server';
import { handleCashfreeWebhook } from '@/lib/cashfree-webhook-handler';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  return handleCashfreeWebhook(req);
}
