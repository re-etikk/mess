import { describe, expect, it } from 'vitest';
import { resolveRequestedPortalRole } from '../lib/auth/portal-role';

describe('portal-specific authorization', () => {
  it('allows an admin with an active owner membership to choose the partner portal', () => {
    expect(resolveRequestedPortalRole('provider', new Set(['admin']), 1)).toBe('provider');
  });

  it('allows the same account into the admin portal only when it has the admin role', () => {
    expect(resolveRequestedPortalRole('admin', new Set(['admin']), 1)).toBe('admin');
    expect(resolveRequestedPortalRole('admin', new Set(['provider']), 1)).toBeNull();
  });

  it('denies provider access without a provider role or active membership', () => {
    expect(resolveRequestedPortalRole('provider', new Set(['customer']), 0)).toBeNull();
  });

  it('does not let an administrator role substitute for customer access', () => {
    expect(resolveRequestedPortalRole('customer', new Set(['admin']), 0)).toBeNull();
  });

  it('fails closed for unknown portal names', () => {
    expect(resolveRequestedPortalRole('superuser', new Set(['admin']), 1)).toBeNull();
  });
});
