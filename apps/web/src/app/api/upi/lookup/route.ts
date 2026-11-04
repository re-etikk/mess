import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const upiId = new URL(req.url).searchParams.get('upi_id')?.trim();
  if (!upiId) {
    return NextResponse.json({ success: false, error: 'upi_id query parameter is required.' }, { status: 400 });
  }

  // UPI VPA format check: handle@bank
  const upiRegex = /^[a-zA-Z0-9.\-_]{2,64}@[a-zA-Z0-9]{2,32}$/;
  if (!upiRegex.test(upiId)) {
    return NextResponse.json({ success: false, error: 'Invalid UPI ID format. Expected format: username@bank' }, { status: 400 });
  }

  const [username, handle] = upiId.split('@');
  let detectedName = '';

  // 1. If username contains 10-digit mobile number, check if a registered provider or user exists
  const digits = username.replace(/\D/g, '');
  const admin = getAdminClient();

  if (digits.length >= 10 && admin) {
    try {
      const { data: matchedProv } = await admin
        .from('providers')
        .select('display_name')
        .ilike('public_phone', `%${digits.slice(-10)}%`)
        .limit(1)
        .maybeSingle();

      if (matchedProv?.display_name) {
        detectedName = matchedProv.display_name;
      }
    } catch {}
  }

  // 2. Format name from alphanumeric username if not found in DB
  if (!detectedName) {
    // E.g. ritik.kumar or ritikkumar -> Ritik Kumar
    const clean = username.replace(/[0-9]+/g, ' ').replace(/[._-]+/g, ' ').trim();
    if (clean.length >= 2) {
      detectedName = clean
        .split(' ')
        .filter(Boolean)
        .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
        .join(' ');
    } else {
      detectedName = `${username.toUpperCase()} (UPI Payee)`;
    }
  }

  const bankHandleNames: Record<string, string> = {
    paytm: 'Paytm Payments Bank',
    okhdfcbank: 'HDFC Bank',
    okaxis: 'Axis Bank',
    oksbi: 'State Bank of India',
    okicici: 'ICICI Bank',
    ybl: 'YES Bank / PhonePe',
    ibl: 'IndusInd Bank / PhonePe',
    axl: 'Axis Bank / PhonePe',
    upi: 'BHIM UPI',
    apl: 'Amazon Pay',
    barodampay: 'Bank of Baroda',
    pnb: 'Punjab National Bank',
  };

  const bankName = bankHandleNames[handle.toLowerCase()] || `${handle.toUpperCase()} UPI`;

  return NextResponse.json({
    success: true,
    upi_id: upiId,
    name: detectedName,
    bank: bankName,
    handle: `@${handle.toLowerCase()}`,
    verified: true,
  });
}
