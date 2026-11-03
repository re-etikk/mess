import { NextRequest } from 'next/server';
import { rejectUnimplementedRedemption } from '@/lib/redemption-not-ready';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  return rejectUnimplementedRedemption(
    req,
    body.token || body.qr_token,
    body.user_id || body.customer_id
  );
}
