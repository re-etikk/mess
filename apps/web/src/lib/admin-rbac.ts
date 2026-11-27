import type { SupabaseClient } from '@supabase/supabase-js';

export type AdminSubRole =
  | 'super_admin'
  | 'operations'
  | 'finance'
  | 'support'
  | 'developer_readonly';

export type AdminCapability =
  | 'overview.read'
  | 'partners.read'
  | 'partners.moderate'
  | 'billing.manage'
  | 'customers.read'
  | 'customers.unmask'
  | 'customers.moderate'
  | 'subscriptions.read'
  | 'subscriptions.moderate'
  | 'support.read'
  | 'support.resolve'
  | 'offers.manage'
  | 'customize.manage'
  | 'finance.read'
  | 'finance.manage'
  | 'operations.read'
  | 'access.manage';

const ROLE_CAPABILITIES: Record<AdminSubRole, ReadonlySet<AdminCapability>> = {
  super_admin: new Set<AdminCapability>([
    'overview.read',
    'partners.read',
    'partners.moderate',
    'billing.manage',
    'customers.read',
    'customers.unmask',
    'customers.moderate',
    'subscriptions.read',
    'subscriptions.moderate',
    'support.read',
    'support.resolve',
    'offers.manage',
    'customize.manage',
    'finance.read',
    'finance.manage',
    'operations.read',
    'access.manage',
  ]),
  operations: new Set<AdminCapability>([
    'overview.read',
    'partners.read',
    'partners.moderate',
    'customers.read',
    'customers.moderate',
    'subscriptions.read',
    'subscriptions.moderate',
    'support.read',
    'support.resolve',
    'offers.manage',
    'customize.manage',
    'finance.read',
    'operations.read',
  ]),
  finance: new Set<AdminCapability>([
    'overview.read',
    'partners.read',
    'billing.manage',
    'customers.read',
    'subscriptions.read',
    'subscriptions.moderate',
    'support.read',
    'support.resolve',
    'offers.manage',
    'finance.read',
    'finance.manage',
    'operations.read',
  ]),
  support: new Set<AdminCapability>([
    'overview.read',
    'partners.read',
    'customers.read',
    'customers.unmask',
    'customers.moderate',
    'subscriptions.read',
    'subscriptions.moderate',
    'support.read',
    'support.resolve',
    'offers.manage',
    'operations.read',
  ]),
  developer_readonly: new Set<AdminCapability>([
    'overview.read',
    'partners.read',
    'customers.read',
    'subscriptions.read',
    'operations.read',
  ]),
};

export function hasAdminCapability(role: AdminSubRole, capability?: AdminCapability): boolean {
  if (!capability) return true;
  return ROLE_CAPABILITIES[role]?.has(capability) ?? false;
}

export async function logAdminAudit(
  admin: SupabaseClient<any> | null | undefined,
  params: {
    actorUserId: string;
    action: string;
    subjectType: string;
    subjectId?: string | null;
    reason?: string | null;
    requestId?: string | null;
    details?: Record<string, unknown>;
  }
): Promise<boolean> {
  if (!admin) return false;
  try {
    const { error } = await admin.from('audit_logs').insert({
      actor_user_id: params.actorUserId || null,
      action: params.action,
      subject_type: params.subjectType,
      subject_id: params.subjectId || null,
      reason: params.reason || null,
      request_id: params.requestId || null,
      sanitized_details: params.details || {},
    });
    if (error) {
      console.error('Audit log write failed:', error.message);
      return false;
    }
    return true;
  } catch (err: any) {
    console.error('Audit log insert exception:', err?.message || 'unknown');
    return false;
  }
}
