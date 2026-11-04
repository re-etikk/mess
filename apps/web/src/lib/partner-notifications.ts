export interface PartnerNotification {
  id: string;
  provider_id: string;
  type: 'pending_payment' | 'plan_upgrade' | 'redemption' | 'info';
  title: string;
  message: string;
  customer_name?: string;
  customer_phone?: string;
  amount_inr?: number;
  subscription_id?: string;
  created_at: string;
  read: boolean;
}

// In-memory partner notifications store
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
  // Keep up to 100 recent notifications
  if (list.length > 100) list.pop();
  partnerNotificationStore.set(notif.provider_id, list);

  return fullNotif;
}

export function getPartnerNotifications(providerId: string): PartnerNotification[] {
  return partnerNotificationStore.get(providerId) || [];
}

export function markPartnerNotificationRead(providerId: string, notifId?: string) {
  const list = partnerNotificationStore.get(providerId) || [];
  if (notifId) {
    const item = list.find((n) => n.id === notifId);
    if (item) item.read = true;
  } else {
    list.forEach((n) => (n.read = true));
  }
}
