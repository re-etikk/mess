import { NextRequest } from 'next/server';
import { rejectUnimplementedRedemption } from '@/lib/redemption-not-ready';

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  return rejectUnimplementedRedemption(req, body.token || body.qr_token);
}
