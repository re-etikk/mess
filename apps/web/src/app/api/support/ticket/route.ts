import { NextRequest, NextResponse } from 'next/server';
import { sendEmailNotification } from '@/lib/notifications';
import { escapeHtml, getClientIp } from '@/lib/auth-session';
import { checkRateLimit } from '@/lib/rate-limiter';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const rl = checkRateLimit(`support:${getClientIp(req)}`, 5, 15 * 60 * 1000);
    if (!rl.isAllowed) {
      return NextResponse.json(
        { success: false, error: 'Too many support requests submitted. Please try again later.' },
        { status: 429 }
      );
    }

    const body = await req.json().catch(() => ({}));
    const name = String(body.name || '').trim().slice(0, 80) || 'User';
    const email = String(body.email || '').trim().slice(0, 120) || 'No email provided';
    const phone = String(body.phone || '').trim().slice(0, 20) || 'No phone provided';
    const category = String(body.category || '').trim().slice(0, 60) || 'General Inquiry';
    const description = String(body.description || '').trim().slice(0, 2500);
    const role = body.role === 'provider' ? 'provider' : 'customer';

    if (!description || description.length < 5) {
      return NextResponse.json(
        { success: false, error: 'Please enter a brief description of your issue.' },
        { status: 400 }
      );
    }

    const supportEmail = process.env.SUPPORT_EMAIL || 'support@thali.store';
    const subject = `[THALI SUPPORT TICKET] ${category} - from ${name} (${role.toUpperCase()})`;
    const html = `
      <div style="font-family: sans-serif; max-width: 600px; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background: #ffffff;">
        <h2 style="color: #0f172a; margin-top: 0;">New Support Request from ${escapeHtml(name)}</h2>
        <div style="background: #f8fafc; padding: 15px; border-radius: 8px; margin-bottom: 20px;">
          <p style="margin: 4px 0;"><strong>Category:</strong> ${escapeHtml(category)}</p>
          <p style="margin: 4px 0;"><strong>Role:</strong> ${escapeHtml(role.toUpperCase())}</p>
          <p style="margin: 4px 0;"><strong>Phone:</strong> ${escapeHtml(phone)}</p>
          <p style="margin: 4px 0;"><strong>Email:</strong> ${escapeHtml(email)}</p>
          <p style="margin: 4px 0;"><strong>Received At:</strong> ${escapeHtml(new Date().toLocaleString('en-IN'))}</p>
        </div>
        <h3 style="color: #334155; margin-bottom: 8px;">Issue Description:</h3>
        <p style="white-space: pre-wrap; background: #fffbeb; padding: 16px; border-radius: 8px; border: 1px solid #fde68a; color: #78350f;">
          ${escapeHtml(description)}
        </p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
        <p style="font-size: 12px; color: #64748b;">
          Submitted via Thali Platform. Reply to ${escapeHtml(email)} or call ${escapeHtml(phone)}.
        </p>
      </div>
    `;

    const emailResult = await sendEmailNotification({
      to: supportEmail,
      subject,
      html,
    });

    return NextResponse.json({
      success: true,
      email_dispatched: emailResult.success,
      message: 'Support ticket submitted successfully! Our team will contact you shortly.',
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err?.message || 'Failed to submit support ticket.' },
      { status: 500 }
    );
  }
}
