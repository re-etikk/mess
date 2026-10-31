import { NextRequest, NextResponse } from 'next/server';
import { sendEmailNotification } from '@/lib/notifications';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const name = body.name?.trim() || 'User';
    const email = body.email?.trim() || 'No email provided';
    const phone = body.phone?.trim() || 'No phone provided';
    const category = body.category?.trim() || 'General Inquiry';
    const description = body.description?.trim();
    const role = body.role || 'customer'; // 'customer' | 'provider'

    if (!description) {
      return NextResponse.json(
        { success: false, error: 'Please enter your issue description.' },
        { status: 400 }
      );
    }

    const supportEmail = process.env.SUPPORT_EMAIL || 'support@thali.store';
    const subject = `[THALI SUPPORT TICKET] ${category} - from ${name} (${role.toUpperCase()})`;
    const html = `
      <div style="font-family: sans-serif; max-width: 600px; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background: #ffffff;">
        <h2 style="color: #0f172a; margin-top: 0;">🆘 New Support Request from ${name}</h2>
        <div style="background: #f8fafc; padding: 15px; border-radius: 8px; margin-bottom: 20px;">
          <p style="margin: 4px 0;"><strong>Category:</strong> ${category}</p>
          <p style="margin: 4px 0;"><strong>Role:</strong> ${role.toUpperCase()}</p>
          <p style="margin: 4px 0;"><strong>Phone:</strong> ${phone}</p>
          <p style="margin: 4px 0;"><strong>Email:</strong> ${email}</p>
          <p style="margin: 4px 0;"><strong>Received At:</strong> ${new Date().toLocaleString('en-IN')}</p>
        </div>
        <h3 style="color: #334155; margin-bottom: 8px;">Issue Description:</h3>
        <p style="white-space: pre-wrap; background: #fffbeb; padding: 16px; border-radius: 8px; border: 1px solid #fde68a; color: #78350f;">
          ${description}
        </p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
        <p style="font-size: 12px; color: #64748b;">
          Submitted via Thali Mobile &amp; Web Platform. Respond directly to ${email} or call ${phone}.
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
      message: '✅ Support ticket submitted successfully! Our team will contact you shortly.',
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Failed to submit support ticket.' },
      { status: 500 }
    );
  }
}
