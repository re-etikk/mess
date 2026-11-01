import { NextRequest } from 'next/server';
import { rejectUnimplementedRedemption } from '@/lib/redemption-not-ready';

/** Legacy alias; do not mutate attendance in process memory. */
export async function POST(req: NextRequest) {
  let body: { token?: string; qr_code?: string };
  try { body = await req.json(); } catch { body = {}; }
  return rejectUnimplementedRedemption(req, body.token || body.qr_code);
}
