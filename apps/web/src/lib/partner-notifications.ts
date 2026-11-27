import { getAdminClient } from './supabase/admin';

export interface PartnerNotification {
  id: string;
  provider_id: string;
  type: 'pending_payment' | 'plan_upgrade' | 'redemption' | 'support' | 'settlement' | 'info';
  title: string;
  message: string;
  customer_name?: string;
  customer_phone?: string;
  amount_inr?: number;
  subscription_id?: string;
  action_tab?: string;
  created_at: string;
  read: boolean;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Warm cache backed by Postgres partner_notifications table
export const partnerNotificationStore = new Map<string, PartnerNotification[]>();

export function addPartnerNotification(notif: Omit<PartnerNotification, 'id' | 'created_at' | 'read'>): PartnerNotification {
  const fullNotif: PartnerNotification = {
    ...notif,
    id: `pnotif-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
    created_at: new Date().toISOString(),
    read: false,
  };

  const list = partnerNotificationStore.get(notif.provider_id) || [];
  list.unshift(fullNotif);
  if (list.length > 100) list.pop();
  partnerNotificationStore.set(notif.provider_id, list);

  if (UUID_RE.test(notif.provider_id)) {
    const admin = getAdminClient();
    if (admin) {
      void admin
        .from('partner_notifications')
        .insert({
          provider_id: notif.provider_id,
          title: notif.title,
          message: notif.message,
          notification_type: notif.type,
          action_tab: notif.action_tab || (notif.type === 'pending_payment' ? 'pending' : null),
          is_read: false,
        })
        .then(() => null, () => null);
    }
  }

  return fullNotif;
}

export function getPartnerNotifications(providerId: string): PartnerNotification[] {
  return partnerNotificationStore.get(providerId) || [];
}

export async function getPersistedPartnerNotifications(providerId: string): Promise<PartnerNotification[]> {
  const admin = getAdminClient();
  if (admin && UUID_RE.test(providerId)) {
    try {
      const { data, error } = await admin
        .from('partner_notifications')
        .select('*')
        .eq('provider_id', providerId)
        .order('created_at', { ascending: false })
        .limit(60);

      if (!error && data && data.length > 0) {
        return data.map((row: any) => ({
          id: String(row.id),
          provider_id: String(row.provider_id),
          type: (row.notification_type || 'info') as PartnerNotification['type'],
          title: String(row.title || 'Update'),
          message: String(row.message || ''),
          action_tab: row.action_tab || undefined,
          created_at: String(row.created_at),
          read: row.is_read === true,
        }));
      }
    } catch {}
  }
  return getPartnerNotifications(providerId);
}

export function markPartnerNotificationRead(providerId: string, notifId?: string) {
  const list = partnerNotificationStore.get(providerId) || [];
  if (notifId) {
    const item = list.find((n) => n.id === notifId);
    if (item) item.read = true;
  } else {
    list.forEach((n) => (n.read = true));
  }

  if (UUID_RE.test(providerId)) {
    const admin = getAdminClient();
    if (admin) {
      let query = admin.from('partner_notifications').update({ is_read: true }).eq('provider_id', providerId);
      if (notifId && UUID_RE.test(notifId)) query = query.eq('id', notifId);
      void query.then(() => null, () => null);
    }
  }
}
