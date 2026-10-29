import { describe, expect, it } from 'vitest';
import { sendProviderApprovalNotice } from '../lib/notifications';

describe('Thali Provider Verification & Notification System', () => {
  it('generates structured credentials and 1-click WhatsApp/SMS links', async () => {
    const notice = await sendProviderApprovalNotice({
      provider_name: 'Shree Krishna Veg Mess',
      phone: '9876543210',
      email: 'owner@krishnamess.in',
      user_id: '9876543210',
      password: 'MessSecure#2026',
      login_url: 'https://mess-beta.vercel.app/auth/login',
    });

    // Check credentials integrity
    expect(notice.credentials.user_id).toBe('9876543210');
    expect(notice.credentials.phone).toBe('9876543210');
    expect(notice.credentials.email).toBe('owner@krishnamess.in');
    expect(notice.credentials.password).toBe('MessSecure#2026');
    expect(notice.credentials.login_url).toBe('https://mess-beta.vercel.app/auth/login');

    // Check message body
    expect(notice.message_text).toContain('Shree Krishna Veg Mess');
    expect(notice.message_text).toContain('9876543210');
    expect(notice.message_text).toContain('MessSecure#2026');
    expect(notice.message_text).toContain('https://mess-beta.vercel.app/auth/login');

    // Check 1-Click WhatsApp deep link
    expect(notice.whatsapp_url).toContain('https://wa.me/919876543210?text=');
    expect(decodeURIComponent(notice.whatsapp_url)).toContain('MessSecure#2026');

    // Check 1-Click SMS link
    expect(notice.sms_url).toContain('sms:+919876543210?body=');
  });

  it('handles custom phone numbers with country code or spaces gracefully', async () => {
    const notice = await sendProviderApprovalNotice({
      provider_name: 'Ritik Homely Kitchen',
      phone: '+91 72501 71036',
      email: 'ritik@example.com',
      user_id: '7250171036',
      password: 'TestPassword123',
    });

    expect(notice.credentials.phone).toBe('7250171036');
    expect(notice.whatsapp_url).toContain('wa.me/917250171036');
    expect(notice.sms_url).toContain('sms:+917250171036');
  });
});
