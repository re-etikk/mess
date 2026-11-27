import { NextRequest, NextResponse } from 'next/server';
import { handleCashfreeWebhook } from '@/lib/cashfree-webhook-handler';

export const dynamic = 'force-dynamic';

export async function GET() {
  return NextResponse.json({ success: true, webhook: 'cashfree_ready' });
}

export async function POST(req: NextRequest) {
  return handleCashfreeWebhook(req);
}
