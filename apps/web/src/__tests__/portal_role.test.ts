import { describe, expect, it } from 'vitest';
import { resolveRequestedPortalRole } from '../lib/auth/portal-role';

describe('portal-specific authorization', () => {
  it('allows an admin with an active owner membership to use the partner portal', () => {
    expect(resolveRequestedPortalRole('provider', new Set(['admin']), 1)).toBe('provider');
  });

  it('allows an admin with a customer role to use the customer portal', () => {
    expect(resolveRequestedPortalRole('customer', new Set(['admin', 'customer']), 1)).toBe('customer');
  });

  it('allows admin access only when the admin role is active', () => {
    expect(resolveRequestedPortalRole('admin', new Set(['admin']), 1)).toBe('admin');
    expect(resolveRequestedPortalRole('admin', new Set(['provider']), 1)).toBeNull();
  });

  it('denies provider access without a provider role or active management membership', () => {
    expect(resolveRequestedPortalRole('provider', new Set(['customer']), 0)).toBeNull();
  });

  it('does not let an admin role substitute for a missing customer role', () => {
    expect(resolveRequestedPortalRole('customer', new Set(['admin']), 0)).toBeNull();
  });

  it('fails closed for unknown portal names', () => {
    expect(resolveRequestedPortalRole('superuser', new Set(['admin']), 1)).toBeNull();
  });
});
