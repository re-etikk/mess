import { NextRequest, NextResponse } from 'next/server';
import { issueProviderQr } from '@/lib/provider-qr';

export async function POST(req: NextRequest) {
  let body: { provider_id?: string; providerId?: string; slot?: string };
  try { body = await req.json(); } catch { return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 }); }
  return issueProviderQr(req, body.provider_id || body.providerId || null, body.slot || null);
}

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  return issueProviderQr(req, params.get('provider_id'), params.get('slot'));
}
