/**
 * Notification Service for Thali
 * Handles sending Email and SMS alerts for provider approval, verification credentials,
 * and customer subscriptions.
 * Supports:
 * - Resend API (Transactional Email) via RESEND_API_KEY
 * - Fast2SMS (Indian SMS Gateway) via FAST2SMS_API_KEY
 * - Twilio (Global SMS) via TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER
 * - 1-Click WhatsApp & SMS direct deep links for manual delivery
 */

import { escapeHtml } from './auth-session';

export interface ProviderApprovalNoticeParams {
  provider_name: string;
  phone: string;
  email: string;
  user_id: string;
  login_url?: string;
}

export interface NotificationDispatchResult {
  email_sent: boolean;
  sms_sent: boolean;
  email_provider: string;
  sms_provider: string;
  message_text: string;
  whatsapp_url: string;
  sms_url: string;
  credentials: {
    user_id: string;
    email: string;
    phone: string;
    login_url: string;
  };
  error?: string;
}

export async function sendProviderApprovalNotice(
  params: ProviderApprovalNoticeParams
): Promise<NotificationDispatchResult> {
  const cleanPhone = params.phone.replace(/\D/g, '');
  const phoneFormatted = cleanPhone.length === 10 ? `+91${cleanPhone}` : `+${cleanPhone}`;
  const phone10Digits = cleanPhone.slice(-10);
  const configuredBaseUrl = process.env.NEXT_PUBLIC_SITE_URL?.replace(/\/$/, '');
  const loginUrl = params.login_url || (configuredBaseUrl ? `${configuredBaseUrl}/partner/login` : '');

  const messageText = `Namaste! Aapka mess "${params.provider_name}" Thali platform par successfully verify aur activate ho gaya hai.

Partner portal: ${loginUrl || 'Please use the partner portal link provided by Thali.'}
Email: ${params.email}
Use the password you registered with, or choose “Forgot password” to reset it.

Ab aap Thali Partner App ya Web Portal me login karke daily QR generate kar sakte hain aur customer subscriptions manage kar sakte hain. Shubhkaamnaye!`;

  const whatsappUrl = `https://wa.me/91${phone10Digits}?text=${encodeURIComponent(messageText)}`;
  const smsUrl = `sms:+91${phone10Digits}?body=${encodeURIComponent(messageText)}`;

  let emailSent = false;
  let emailProvider = 'none';
  let smsSent = false;
  let smsProvider = 'none';

  // 1. Try Resend API for Email
  const resendApiKey = process.env.RESEND_API_KEY;
  if (resendApiKey && params.email && params.email.includes('@')) {
    try {
      const emailRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: process.env.RESEND_FROM_EMAIL || 'Thali Notifications <onboarding@resend.dev>',
          to: [params.email],
          subject: `Your mess "${params.provider_name}" is verified on Thali`,
          text: messageText,
          html: `
            <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e4e4e7; border-radius: 12px; background: #ffffff;">
              <h2 style="color: #18181b; margin-top: 0;">Your kitchen is verified on Thali</h2>
              <p style="color: #475569; font-size: 15px; line-height: 1.6;">
                Namaste! Your kitchen <strong>${escapeHtml(params.provider_name)}</strong> has been reviewed and approved by the Thali operations team.
              </p>
              
              <div style="background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 8px; padding: 16px; margin: 20px 0;">
                <h4 style="margin: 0 0 10px 0; color: #0f172a;">Your Partner Login Credentials:</h4>
                <p style="margin: 4px 0; font-size: 14px;"><strong>Portal Link:</strong> <a href="${escapeHtml(loginUrl)}">${escapeHtml(loginUrl)}</a></p>
                <p style="margin: 4px 0; font-size: 14px;"><strong>User ID / Phone:</strong> ${escapeHtml(phone10Digits)}</p>
                <p style="margin: 4px 0; font-size: 14px;"><strong>Registered Email:</strong> ${escapeHtml(params.email)}</p>
              </div>

              <a href="${escapeHtml(loginUrl)}" style="display: inline-block; background: #0f172a; color: #ffffff; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold; font-size: 14px;">
                Open Kitchen Hub &rarr;
              </a>

              <p style="color: #64748b; font-size: 13px; margin-top: 24px;">
                Sign in with your registered account. Use “Forgot password” if you need to reset it.
              </p>
            </div>
          `,
        }),
      });

      if (emailRes.ok) {
        emailSent = true;
        emailProvider = 'resend';
      } else {
        const errJson = await emailRes.json().catch(() => ({}));
        console.warn('Resend email dispatch error:', errJson);
        // On Resend free tier without custom domain, sending to other emails is restricted.
        // Forward admin confirmation copy to the registered account owner email
        const adminEmail = process.env.ADMIN_EMAIL || process.env.RESEND_ACCOUNT_EMAIL;
        if (adminEmail && params.email !== adminEmail) {
          try {
            const adminCopyRes = await fetch('https://api.resend.com/emails', {
              method: 'POST',
              headers: {
                Authorization: `Bearer ${resendApiKey}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                from: process.env.RESEND_FROM_EMAIL || 'Thali Notifications <onboarding@resend.dev>',
                to: [adminEmail],
                subject: `[Admin Alert] Mess Verified: "${params.provider_name}"`,
                text: messageText,
                html: `
                  <div style="font-family: sans-serif; max-width: 600px; padding: 20px; border: 1px solid #cbd5e1; border-radius: 8px;">
                    <h3>Kitchen Partner Verified: ${escapeHtml(params.provider_name)}</h3>
                    <p><strong>Owner Email:</strong> ${escapeHtml(params.email)}</p>
                    <p><strong>Phone:</strong> ${escapeHtml(phone10Digits)}</p>
                    <p><strong>Login URL:</strong> <a href="${escapeHtml(loginUrl)}">${escapeHtml(loginUrl)}</a></p>
                  </div>
                `,
              }),
            });
            if (adminCopyRes.ok) {
              emailSent = true;
              emailProvider = 'resend (delivered to admin)';
            }
          } catch {}
        }
      }
    } catch (e: any) {
      console.warn('Failed to dispatch Resend email:', e?.message || e);
    }
  }

  // 2. Try Fast2SMS for Indian SMS
  const fast2SmsKey = process.env.FAST2SMS_API_KEY;
  if (fast2SmsKey && phone10Digits.length === 10) {
    try {
      const smsRes = await fetch('https://www.fast2sms.com/dev/bulkV2', {
        method: 'POST',
        headers: {
          authorization: fast2SmsKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          route: 'q',
          message: `Thali Mess verified: ${params.provider_name}. Sign in at ${loginUrl} with your registered account. Use Forgot password if needed.`,
          language: 'english',
          flash: 0,
          numbers: phone10Digits,
        }),
      });

      const smsJson = await smsRes.json().catch(() => ({}));
      if (smsRes.ok && (smsJson.return === true || smsJson.status_code === 200)) {
        smsSent = true;
        smsProvider = 'fast2sms';
      } else {
        console.warn('Fast2SMS dispatch notice:', smsJson.message || smsJson);
      }
    } catch (e: any) {
      console.warn('Fast2SMS exception:', e?.message || e);
    }
  }

  // 3. Try Twilio if Fast2SMS not configured
  const twilioSid = process.env.TWILIO_ACCOUNT_SID;
  const twilioToken = process.env.TWILIO_AUTH_TOKEN;
  const twilioPhone = process.env.TWILIO_PHONE_NUMBER;
  if (!smsSent && twilioSid && twilioToken && twilioPhone) {
    try {
      const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${twilioSid}/Messages.json`;
      const formParams = new URLSearchParams();
      formParams.append('To', phoneFormatted);
      formParams.append('From', twilioPhone);
      formParams.append('Body', `Thali Mess verified: ${params.provider_name}. Sign in at ${loginUrl} with your registered account. Use Forgot password if needed.`);

      const twilioRes = await fetch(twilioUrl, {
        method: 'POST',
        headers: {
          Authorization: 'Basic ' + Buffer.from(`${twilioSid}:${twilioToken}`).toString('base64'),
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formParams.toString(),
      });

      if (twilioRes.ok) {
        smsSent = true;
        smsProvider = 'twilio';
      }
    } catch (e: any) {
      console.warn('Twilio SMS exception:', e?.message || e);
    }
  }

  return {
    email_sent: emailSent,
    sms_sent: smsSent,
    email_provider: emailProvider,
    sms_provider: smsProvider,
    message_text: messageText,
    whatsapp_url: whatsappUrl,
    sms_url: smsUrl,
    credentials: {
      user_id: phone10Digits,
      email: params.email,
      phone: phone10Digits,
      login_url: loginUrl,
    },
  };
}

export async function sendEmailNotification(params: {
  to: string;
  subject: string;
  html: string;
  text?: string;
}): Promise<{ success: boolean; error?: string }> {
  const resendApiKey = process.env.RESEND_API_KEY;
  if (!resendApiKey) {
    console.warn('RESEND_API_KEY is not configured');
    return { success: false, error: 'RESEND_API_KEY missing' };
  }

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: process.env.RESEND_FROM_EMAIL || 'Thali Support <support@thali.store>',
        to: [params.to],
        subject: params.subject,
        html: params.html,
        text: params.text || params.html.replace(/<[^>]+>/g, ''),
      }),
    });

    if (res.ok) {
      return { success: true };
    }
    const errData = await res.json().catch(() => ({}));
    return { success: false, error: errData.message || 'Resend API returned error' };
  } catch (err: any) {
    return { success: false, error: err.message || 'Unknown network error' };
  }
}

export interface CustomerInvoiceEmailParams {
  to: string;
  customerName: string;
  providerName: string;
  planName: string;
  subscriptionId: string;
  amountInr: number;
  discountInr?: number;
  promoCode?: string;
  paymentMode: string;
  paymentStatus: string;
  startsAtIso: string;
  expiresAtIso: string;
  packagingPreference?: string;
  transactionRef?: string;
}

export async function sendCustomerInvoiceEmail(
  params: CustomerInvoiceEmailParams
): Promise<{ success: boolean; error?: string }> {
  const email = (params.to || '').trim();
  if (!email || !email.includes('@')) {
    return { success: false, error: 'Customer email missing' };
  }

  const fmtDate = (iso: string) => {
    try {
      return new Date(iso).toLocaleDateString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        timeZone: 'Asia/Kolkata',
      });
    } catch {
      return iso.slice(0, 10);
    }
  };

  const payLabel =
    params.paymentMode === 'counter_cash'
      ? 'Pay Cash at Counter'
      : 'Cashfree Online (UPI / Cards)';
  const pkgLabel =
    params.packagingPreference === 'disposable'
      ? 'Disposable Container'
      : params.packagingPreference === 'dine_in'
      ? 'Dine-in / Counter Pickup'
      : 'Reusable Tiffin';

  const invoiceNo = escapeHtml(`THL-${params.subscriptionId.slice(0, 8).toUpperCase()}`);
  const discountRow =
    params.discountInr && params.discountInr > 0
      ? `<tr><td style="padding:8px 0;color:#52525c;">Promo Discount${params.promoCode ? ` (${escapeHtml(params.promoCode)})` : ''}</td><td style="padding:8px 0;text-align:right;color:#16a34a;font-weight:700;">-₹${Math.round(params.discountInr)}</td></tr>`
      : '';

  const html = `
    <div style="font-family:Urbanist,Arial,sans-serif;max-width:600px;margin:0 auto;background:#fafafa;padding:24px;">
      <div style="background:#ffffff;border:1px solid #e4e4e7;border-radius:16px;overflow:hidden;">
        <div style="background:#e95f35;padding:22px 24px;color:#ffffff;">
          <div style="font-size:12px;font-weight:700;letter-spacing:1px;text-transform:uppercase;opacity:0.9;">Thali Subscription Invoice</div>
          <h1 style="margin:6px 0 2px;font-size:22px;font-weight:800;">${escapeHtml(params.providerName)}</h1>
          <div style="font-size:13px;opacity:0.92;">Invoice #${invoiceNo}</div>
        </div>
        <div style="padding:24px;color:#18181b;">
          <p style="margin:0 0 14px;font-size:14px;color:#52525c;">
            Hi <strong>${escapeHtml(params.customerName || 'Subscriber')}</strong>, thank you for subscribing via Thali. Your meal pass details are below.
          </p>
          <div style="background:#fff3ee;border:1px solid #fed7aa;border-radius:10px;padding:12px 14px;margin-bottom:18px;font-size:13px;color:#a83b1c;font-weight:700;">
            Status: ${escapeHtml(params.paymentStatus)}
          </div>
          <table style="width:100%;border-collapse:collapse;font-size:13.5px;">
            <tr><td style="padding:8px 0;color:#71717b;border-bottom:1px solid #f4f4f5;">Meal Plan</td><td style="padding:8px 0;text-align:right;font-weight:700;border-bottom:1px solid #f4f4f5;">${escapeHtml(params.planName)}</td></tr>
            <tr><td style="padding:8px 0;color:#71717b;border-bottom:1px solid #f4f4f5;">Validity Period</td><td style="padding:8px 0;text-align:right;font-weight:600;border-bottom:1px solid #f4f4f5;">${escapeHtml(fmtDate(params.startsAtIso))} - ${escapeHtml(fmtDate(params.expiresAtIso))}</td></tr>
            <tr><td style="padding:8px 0;color:#71717b;border-bottom:1px solid #f4f4f5;">Tiffin / Packaging</td><td style="padding:8px 0;text-align:right;font-weight:600;border-bottom:1px solid #f4f4f5;">${escapeHtml(pkgLabel)}</td></tr>
            <tr><td style="padding:8px 0;color:#71717b;border-bottom:1px solid #f4f4f5;">Payment Method</td><td style="padding:8px 0;text-align:right;font-weight:600;border-bottom:1px solid #f4f4f5;">${escapeHtml(payLabel)}</td></tr>
            ${params.transactionRef ? `<tr><td style="padding:8px 0;color:#71717b;border-bottom:1px solid #f4f4f5;">Reference ID</td><td style="padding:8px 0;text-align:right;font-weight:600;border-bottom:1px solid #f4f4f5;">${escapeHtml(params.transactionRef)}</td></tr>` : ''}
            ${discountRow}
            <tr><td style="padding:14px 0 4px;font-size:16px;font-weight:800;">Total Amount</td><td style="padding:14px 0 4px;text-align:right;font-size:18px;font-weight:800;color:#e95f35;">₹${Math.round(params.amountInr)}</td></tr>
          </table>
          <p style="margin:20px 0 0;font-size:12px;color:#71717b;">
            Manage daily meals, skips, or pauses anytime inside the Thali app. Need help? Contact support@thali.store.
          </p>
        </div>
      </div>
    </div>
  `;

  return sendEmailNotification({
    to: email,
    subject: `Thali Invoice #${invoiceNo} — ${params.planName} at ${params.providerName}`,
    html,
  });
}
