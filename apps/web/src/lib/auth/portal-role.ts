export type PortalRole = 'admin' | 'provider' | 'customer';

/** Resolve the requested workspace independently for accounts with multiple roles. */
export function resolveRequestedPortalRole(
  requestedRole: string | undefined,
  roles: ReadonlySet<string>,
  activeProviderManagementMembershipCount: number,
): PortalRole | null {
  if (requestedRole === 'admin') return roles.has('admin') ? 'admin' : null;
  if (requestedRole === 'provider') {
    return roles.has('provider') || activeProviderManagementMembershipCount > 0 ? 'provider' : null;
  }
  if (requestedRole === 'customer') return roles.has('customer') ? 'customer' : null;
  if (requestedRole) return null;

  if (roles.has('admin')) return 'admin';
  if (roles.has('provider') || activeProviderManagementMembershipCount > 0) return 'provider';
  return roles.has('customer') ? 'customer' : null;
}
