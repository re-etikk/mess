import { describe, expect, it } from 'vitest';
import { sendProviderApprovalNotice } from '../lib/notifications';

describe('Thali Provider Verification & Notification System', () => {
  it('generates a sign-in notice and never sends a password', async () => {
    const notice = await sendProviderApprovalNotice({
      provider_name: 'Shree Krishna Veg Mess',
      phone: '9876543210',
      email: 'owner@krishnamess.in',
      user_id: '9876543210',
      login_url: 'https://mess-beta.vercel.app/auth/login',
    });

    // Account identifiers may be included, but passwords must never be returned or sent.
    expect(notice.credentials.user_id).toBe('9876543210');
    expect(notice.credentials.phone).toBe('9876543210');
    expect(notice.credentials.email).toBe('owner@krishnamess.in');
    expect('password' in notice.credentials).toBe(false);
    expect(notice.credentials.login_url).toBe('https://mess-beta.vercel.app/auth/login');

    // Check message body
    expect(notice.message_text).toContain('Shree Krishna Veg Mess');
    expect(notice.message_text).toContain('https://mess-beta.vercel.app/auth/login');

    // Check 1-Click WhatsApp deep link
    expect(notice.whatsapp_url).toContain('https://wa.me/919876543210?text=');

    // Check 1-Click SMS link
    expect(notice.sms_url).toContain('sms:+919876543210?body=');
  });

  it('handles custom phone numbers with country code or spaces gracefully', async () => {
    const notice = await sendProviderApprovalNotice({
      provider_name: 'Ritik Homely Kitchen',
      phone: '+91 72501 71036',
      email: 'ritik@example.com',
      user_id: '7250171036',
    });

    expect(notice.credentials.phone).toBe('7250171036');
    expect(notice.whatsapp_url).toContain('wa.me/917250171036');
    expect(notice.sms_url).toContain('sms:+917250171036');
  });
});
