export type PortalRole = 'admin' | 'provider' | 'customer';

/** Resolve one portal at a time so a multi-role account can access each authorized workspace. */
export function resolveRequestedPortalRole(
  requestedRole: string | undefined,
  roles: ReadonlySet<string>,
  activeProviderMembershipCount: number,
): PortalRole | null {
  if (requestedRole === 'admin') return roles.has('admin') ? 'admin' : null;
  if (requestedRole === 'provider') return roles.has('provider') || activeProviderMembershipCount > 0 ? 'provider' : null;
  if (requestedRole === 'customer') return roles.has('customer') ? 'customer' : null;
  if (requestedRole) return null;
  if (roles.has('admin')) return 'admin';
  if (roles.has('provider') || activeProviderMembershipCount > 0) return 'provider';
  return roles.has('customer') ? 'customer' : null;
}
