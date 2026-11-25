import { afterEach, describe, expect, it, vi } from 'vitest';
import { NextRequest } from 'next/server';

vi.mock('@/lib/supabase/admin', () => ({
  getAdminClient: () => null,
}));

import { POST } from '../app/api/auth/otp/send/route';

afterEach(() => {
  vi.unstubAllEnvs();
  vi.restoreAllMocks();
});

describe('POST /api/auth/otp/send', () => {
  it('rejects phone identifiers so SMS OTP cannot be requested', async () => {
    vi.stubEnv('NODE_ENV', 'production');
    const fetch = vi.spyOn(globalThis, 'fetch');

    const request = new NextRequest('http://localhost/api/auth/otp/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '9876543210' }),
    });

    const response = await POST(request);
    const body = await response.json();

    expect(response.status).toBe(400);
    expect(body).toMatchObject({
      success: false,
      error: 'A valid email address is required. Phone OTP is disabled.',
    });
    expect(body).not.toHaveProperty('test_otp');
    expect(fetch).not.toHaveBeenCalled();
    fetch.mockRestore();
  });
});
