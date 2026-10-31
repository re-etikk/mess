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

export interface ProviderApprovalNoticeParams {
  provider_name: string;
  phone: string;
  email: string;
  user_id: string;
  password?: string;
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
    password: string;
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
  const password = params.password || 'MessOwner@2026';
  const loginUrl = params.login_url || 'https://mess-beta.vercel.app/auth/login';

  const messageText = `Namaste! Aapka mess "${params.provider_name}" Thali platform par successfully verify aur activate ho gaya hai.

Aapke Kitchen Partner Login Credentials:
• Portal URL: ${loginUrl}
• User ID / Phone: ${phone10Digits}
• Email: ${params.email}
• Password: ${password}

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
          subject: `🎉 Your mess "${params.provider_name}" is verified on Thali - Login Credentials`,
          text: messageText,
          html: `
            <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 12px; background: #ffffff;">
              <h2 style="color: #0f172a; margin-top: 0;">🎉 Congratulations! Your mess is verified.</h2>
              <p style="color: #475569; font-size: 15px; line-height: 1.6;">
                Namaste! Your kitchen <strong>${params.provider_name}</strong> has been reviewed and approved by the Thali operations team.
              </p>
              
              <div style="background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 8px; padding: 16px; margin: 20px 0;">
                <h4 style="margin: 0 0 10px 0; color: #0f172a;">Your Partner Login Credentials:</h4>
                <p style="margin: 4px 0; font-size: 14px;"><strong>Portal Link:</strong> <a href="${loginUrl}">${loginUrl}</a></p>
                <p style="margin: 4px 0; font-size: 14px;"><strong>User ID / Phone:</strong> ${phone10Digits}</p>
                <p style="margin: 4px 0; font-size: 14px;"><strong>Registered Email:</strong> ${params.email}</p>
                <p style="margin: 4px 0; font-size: 14px;"><strong>Password:</strong> <code style="background: #e2e8f0; padding: 2px 6px; border-radius: 4px;">${password}</code></p>
              </div>

              <a href="${loginUrl}" style="display: inline-block; background: #0f172a; color: #ffffff; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold; font-size: 14px;">
                Open Kitchen Hub &rarr;
              </a>

              <p style="color: #64748b; font-size: 13px; margin-top: 24px;">
                You can also open the Thali Kitchen Partner Mobile App and sign in with your phone number and password to generate today's daily QR code.
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
        const adminEmail = process.env.ADMIN_EMAIL || process.env.RESEND_ACCOUNT_EMAIL || 'admin@thali.store';
        if (params.email !== adminEmail) {
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
                subject: `🎉 [Admin Alert] Mess Verified: "${params.provider_name}" Credentials`,
                text: messageText,
                html: `
                  <div style="font-family: sans-serif; max-width: 600px; padding: 20px; border: 1px solid #cbd5e1; border-radius: 8px;">
                    <h3>Kitchen Partner Verified: ${params.provider_name}</h3>
                    <p><strong>Owner Email:</strong> ${params.email}</p>
                    <p><strong>Phone:</strong> ${phone10Digits}</p>
                    <p><strong>Password:</strong> <code>${password}</code></p>
                    <p><strong>Login URL:</strong> <a href="${loginUrl}">${loginUrl}</a></p>
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
          message: `Thali Mess Verified! Kitchen: ${params.provider_name}. Login at ${loginUrl} with Phone: ${phone10Digits}, Pass: ${password}`,
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
      formParams.append('Body', `Thali Mess Verified! Kitchen: ${params.provider_name}. Login at ${loginUrl} with Phone: ${phone10Digits}, Pass: ${password}`);

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
      password,
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
