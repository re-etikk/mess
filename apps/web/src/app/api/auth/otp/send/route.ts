import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

function maskIdentifier(val: string): string {
  if (val.includes('@')) {
    const [user, domain] = val.split('@');
    return `${user.slice(0, 2)}***@${domain}`;
  }
  const digits = val.replace(/\D/g, '');
  return `${digits.slice(0, 2)}******${digits.slice(-2)}`;
}

export async function POST(req: NextRequest) {
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body' }, { status: 400 });
  }

  const raw = String(body.identifier || body.email || body.phone || '').trim();
  const purpose = String(body.purpose || 'profile_update');

  if (!raw) {
    return NextResponse.json({ success: false, error: 'Phone or email is required.' }, { status: 400 });
  }

  const isEmail = raw.includes('@');
  const cleanPhone = raw.replace(/\D/g, '');

  if (!isEmail && cleanPhone.length < 10) {
    return NextResponse.json({ success: false, error: 'Please enter a valid 10-digit phone number or email address.' }, { status: 400 });
  }

  const identifier = isEmail ? raw.toLowerCase() : cleanPhone.slice(-10);
  const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

  const admin = getAdminClient();
  if (admin) {
    try {
      // Invalidate prior unused OTPs for this identifier
      await admin.from('auth_otps').delete().eq('identifier', identifier);

      // Insert new OTP
      await admin.from('auth_otps').insert({
        identifier,
        otp_code: otpCode,
        purpose,
        expires_at: expiresAt,
        verified: false,
        attempts: 0,
      });
    } catch (e: any) {
      console.warn('DB auth_otps insert error:', e?.message);
    }
  }

  // Dispatch Email or SMS
  let delivered = false;

  // 1. Send via Resend if email
  if (isEmail) {
    const resendApiKey = process.env.RESEND_API_KEY;
    if (resendApiKey) {
      try {
        const res = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${resendApiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from: process.env.RESEND_FROM_EMAIL || 'Thali Security <onboarding@resend.dev>',
            to: [identifier],
            subject: `🔒 ${otpCode} is your Thali verification code`,
            text: `Your Thali verification code is ${otpCode}. Valid for 10 minutes. Do not share with anyone.`,
            html: `
              <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 500px; margin: 0 auto; padding: 28px; background: #ffffff; border: 1px solid #E2E8F0; border-radius: 16px;">
                <div style="display: flex; align-items: center; margin-bottom: 20px;">
                  <span style="font-size: 24px; font-weight: 900; color: #FF6B1A;">THALI</span>
                </div>
                <h2 style="color: #0F172A; font-size: 20px; font-weight: 800; margin: 0 0 8px 0;">Verify your Thali account</h2>
                <p style="color: #64748B; font-size: 14px; margin: 0 0 24px 0;">Use the 6-digit one-time code below to verify your changes.</p>
                <div style="background: #FFF7ED; border: 2px dashed #F97316; border-radius: 12px; padding: 18px; text-align: center; margin-bottom: 24px;">
                  <span style="font-size: 36px; font-weight: 900; letter-spacing: 8px; color: #EA580C; font-family: monospace;">${otpCode}</span>
                </div>
                <p style="color: #64748B; font-size: 12px; line-height: 1.5; margin: 0 0 8px 0;">This code is valid for <strong>10 minutes</strong>. Never share this code with anyone.</p>
                <p style="color: #94A3B8; font-size: 11px; margin: 0;">If you didn't request this code, you can safely ignore this email.</p>
              </div>
            `,
          }),
        });
        if (res.ok) delivered = true;
      } catch (err: any) {
        console.warn('Resend email error:', err?.message);
      }
    }
  } else {
    // 2. Send via Fast2SMS if Indian phone
    const fast2SmsKey = process.env.FAST2SMS_API_KEY;
    if (fast2SmsKey && identifier.length === 10) {
      try {
        const res = await fetch('https://www.fast2sms.com/dev/bulkV2', {
          method: 'POST',
          headers: {
            authorization: fast2SmsKey,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            route: 'q',
            message: `Your Thali verification code is ${otpCode}. Valid for 10 minutes. Do not share this OTP with anyone.`,
            language: 'english',
            numbers: identifier,
          }),
        });
        if (res.ok) delivered = true;
      } catch (err: any) {
        console.warn('Fast2SMS error:', err?.message);
      }
    }
  }

  return NextResponse.json({
    success: true,
    delivered,
    identifier: maskIdentifier(identifier),
    message: `Verification code sent to ${maskIdentifier(identifier)}.`,
    // For development convenience in testing if SMS/email gateway is offline
    test_otp: process.env.NODE_ENV !== 'production' ? otpCode : undefined,
  });
}
