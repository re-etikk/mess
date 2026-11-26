import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { randomInt } from 'crypto';
import { getClientIp } from '@/lib/auth-session';
import { checkRateLimit } from '@/lib/rate-limiter';

export const dynamic = 'force-dynamic';
export const fetchCache = 'force-no-store';

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

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(raw)) {
    return NextResponse.json({ success: false, error: 'A valid email address is required. Phone OTP is disabled.' }, { status: 400 });
  }

  const identifier = raw.toLowerCase();
  const rl = checkRateLimit(`otp_send:${getClientIp(req)}:${identifier}`, 5, 15 * 60 * 1000);
  if (!rl.isAllowed) {
    return NextResponse.json(
      { success: false, error: 'Too many verification code requests. Please wait a few minutes.' },
      { status: 429 }
    );
  }
  const otpCode = randomInt(100000, 1000000).toString();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: false, error: 'Authentication service is not configured on this server.' }, { status: 503 });
  }
  const nowIso = new Date().toISOString();
  const { error: cleanupError } = await admin
    .from('auth_otps')
    .delete()
    .eq('identifier', identifier)
    .or(`verified.eq.true,expires_at.lt.${nowIso}`);
  if (cleanupError) {
    console.warn('Could not clean previous expired OTPs:', cleanupError.message);
  }
  const { error: insertError } = await admin.from('auth_otps').insert({
    identifier,
    otp_code: otpCode,
    purpose,
    expires_at: expiresAt,
    verified: false,
    attempts: 0,
  });
  if (insertError) {
    console.error('Could not save OTP:', insertError.message);
    return NextResponse.json({ success: false, error: 'Could not send the verification code. Please try again later.' }, { status: 503 });
  }

  // Dispatch the verification code by email.
  let delivered = false;
  let deliveryNote: string | undefined;

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
          subject: `${otpCode} is your Thali verification code`,
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
      if (res.ok) {
        delivered = true;
      } else {
        const errJson = await res.json().catch(() => null);
        deliveryNote = errJson?.message || `Email provider HTTP ${res.status}`;
      }
    } catch (err: any) {
      deliveryNote = err?.message;
      console.warn('Resend email error:', err?.message);
    }
  } else {
    deliveryNote = 'RESEND_API_KEY not configured';
  }

  if (!delivered && process.env.NODE_ENV === 'production') {
    console.error('OTP email delivery failed:', deliveryNote || 'No email provider is configured');
    return NextResponse.json(
      { success: false, error: 'Could not send the verification code. Please try again later.' },
      { status: deliveryNote?.includes('not configured') ? 503 : 502 }
    );
  }

  return NextResponse.json({
    success: true,
    delivered,
    identifier: maskIdentifier(identifier),
    message: delivered
      ? `Verification code sent to ${maskIdentifier(identifier)}.`
      : `Verification code generated. Valid for 10 minutes.`,
    delivery_note: !delivered && process.env.NODE_ENV !== 'production' ? deliveryNote : undefined,
    test_otp: process.env.NODE_ENV !== 'production' ? otpCode : undefined,
  });
}
