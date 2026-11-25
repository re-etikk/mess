import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { NextRequest } from 'next/server';

const mocks = vi.hoisted(() => ({
  getAdminClient: vi.fn(),
}));

vi.mock('@/lib/supabase/admin', () => ({
  getAdminClient: mocks.getAdminClient,
}));

import { POST } from '../app/api/auth/otp/verify/route';

describe('POST /api/auth/otp/verify', () => {
  const createUser = vi.fn();
  const listUsers = vi.fn();
  let admin: any;

  beforeEach(() => {
    vi.clearAllMocks();
    const record = {
      id: 'otp-row-1',
      identifier: 'person@example.com',
      otp_code: '123456',
      expires_at: new Date(Date.now() + 60_000).toISOString(),
      attempts: 0,
    };
    const profile = {
      id: 'existing-user-id',
      email: 'person@example.com',
      display_name: 'Existing Person',
      phone_e164: null,
    };
    const otpSelect = {
      select: () => otpSelect,
      eq: () => otpSelect,
      order: () => otpSelect,
      limit: () => otpSelect,
      maybeSingle: async () => ({ data: record, error: null }),
    };
    const otpUpdate = {
      update: () => otpUpdate,
      eq: async () => ({ error: null }),
    };
    const profileSelect = {
      select: () => profileSelect,
      eq: () => profileSelect,
      limit: async () => ({ data: [profile], error: null }),
    };
    admin = {
      from: (table: string) => {
        if (table === 'auth_otps') return { select: () => otpSelect, update: () => otpUpdate };
        if (table === 'profiles') return profileSelect;
        if (table === 'user_roles') {
          return { upsert: async () => ({ error: null }) };
        }
        throw new Error(`Unexpected table: ${table}`);
      },
      auth: {
        admin: {
          createUser,
          listUsers,
        },
      },
    };
    mocks.getAdminClient.mockReturnValue(admin);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('rejects phone identifiers instead of verifying an SMS OTP', async () => {
    const request = new NextRequest('http://localhost/api/auth/otp/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '9876543210', otp: '123456' }),
    });

    const response = await POST(request);
    const body = await response.json();

    expect(response.status).toBe(400);
    expect(body.error).toContain('Phone OTP is disabled');
    expect(createUser).not.toHaveBeenCalled();
  });

  it('reuses the existing account ID for email OTP sign-in', async () => {
    const request = new NextRequest('http://localhost/api/auth/otp/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: 'PERSON@example.com',
        otp: '123456',
        create_session: true,
        role: 'customer',
      }),
    });

    const response = await POST(request);
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.user.id).toBe('existing-user-id');
    expect(createUser).not.toHaveBeenCalled();
  });

  it('finds an existing auth account beyond the first user page instead of creating another', async () => {
    const existingUser = { id: 'existing-user-id', email: 'person@example.com' };
    const profile = {
      id: existingUser.id,
      email: null,
      display_name: 'Existing Person',
      phone_e164: null,
    };
    const updatedProfile = { ...profile, email: existingUser.email };
    let filter: { column: string; value: string } | null = null;
    const profileQuery = {
      select: () => profileQuery,
      update: () => profileQuery,
      eq: (column: string, value: string) => {
        filter = { column, value };
        return profileQuery;
      },
      limit: async () => ({ data: [], error: null }),
      maybeSingle: async () => ({
        data: filter?.column === 'id' ? (filter.value === profile.id ? profile : null) : updatedProfile,
        error: null,
      }),
    };
    const originalFrom = admin.from;
    admin.from = (table: string) => table === 'profiles' ? profileQuery : originalFrom(table);
    listUsers.mockImplementation(async ({ page }: { page: number }) => ({
      data: {
        users: page === 1
          ? Array.from({ length: 200 }, (_, index) => ({ id: `other-${index}`, email: `other-${index}@example.com` }))
          : [existingUser],
      },
      error: null,
    }));

    const request = new NextRequest('http://localhost/api/auth/otp/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: 'person@example.com',
        otp: '123456',
        create_session: true,
        role: 'customer',
      }),
    });

    const response = await POST(request);
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.user.id).toBe(existingUser.id);
    expect(listUsers).toHaveBeenCalledTimes(2);
    expect(createUser).not.toHaveBeenCalled();
  });
});
