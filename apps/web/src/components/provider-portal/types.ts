export type PartnerTab =
  | 'overview'
  | 'queue'
  | 'menu'
  | 'plans'
  | 'approvals'
  | 'subscribers'
  | 'riders'
  | 'finance'
  | 'profile'
  | 'support';

export interface PartnerSession {
  providerId: string;
  businessName: string;
  email: string;
  phone: string;
  status: string;
  billingStatus?: string;
}

export interface PartnerMetrics {
  today_scans_count: number;
  total_scans: number;
  unbilled_scans: number;
  active_subscribers: number;
  active_plans_count: number;
  pending_cash_count: number;
  pending_cash_inr: number;
  online_settled_inr: number;
  average_rating: number | null;
  reviews_count: number;
}

export interface PartnerNotification {
  id: string;
  type: string;
  title: string;
  message: string;
  read: boolean;
  created_at: string;
  customer_name?: string;
  subscription_id?: string;
}

export interface ForecastSlot {
  slot: string;
  expected_diners: number;
  dine_in_count: number;
  delivery_count: number;
  avg_last_4_weeks: number;
}

export interface KitchenForecast {
  slots: ForecastSlot[];
  churn_alerts: Array<{
    customer_id: string;
    customer_name: string;
    customer_phone?: string;
    days_absent?: number;
    reason?: string;
  }>;
  waste_saved_inr?: number;
  summary?: string;
}

export interface KitchenQueueItem {
  subscription_id: string;
  customer_id: string;
  customer_name: string;
  customer_phone?: string;
  plan_name: string;
  slot: string;
  fulfillment_mode: 'delivery' | 'pickup' | string;
  status: string;
  eta_minutes?: number | null;
  drop_address?: string;
  rider_id?: string | null;
  rider_name?: string | null;
  rider_phone?: string | null;
}

export interface MenuDish {
  id?: string;
  name: string;
  is_add_on: boolean;
  item_kind: 'included' | 'addon' | 'special';
  price_paise: number;
  price_inr: number;
  active: boolean;
  day_of_week: string;
  slot: string;
  dietary_type: string;
  description?: string;
}

export interface MealSlotConfig {
  id: string;
  name: string;
  starts_at_local: string;
  ends_at_local: string;
  active: boolean;
  daily_capacity?: number | null;
  single_meal_price_paise?: number | null;
  single_meal_price_inr?: number | null;
}

export interface SubscriptionPlanItem {
  id: string;
  name: string;
  description?: string;
  plan_type: string;
  duration_days: number;
  duration_months?: number;
  meal_credits?: number | null;
  price_paise: number;
  price_inr: number;
  discount_percent?: number | null;
  published: boolean;
  active: boolean;
}

export interface PendingApprovalItem {
  id: string;
  customer_id: string;
  customer_name: string;
  customer_phone: string;
  plan_name: string;
  plan_type: string;
  price_paise: number;
  price_inr: number;
  payment_mode: string;
  created_at: string;
}

export interface SubscriberItem {
  id: string;
  customer_id: string;
  customer_name: string;
  customer_phone: string;
  plan_id?: string;
  plan_name: string;
  plan_type: string;
  status: string;
  starts_at?: string;
  expires_at?: string;
  remaining_meal_credits?: number | null;
  initial_meal_credits?: number | null;
  price_paid_paise: number;
  created_at: string;
}

export interface CounterOrderItem {
  id: string;
  customer_name: string;
  customer_phone?: string;
  slot: string;
  items_summary: string;
  amount_paise: number;
  amount_inr: number;
  payment_mode: string;
  status: string;
  created_at: string;
}

export interface DeliveryRider {
  id: string;
  name: string;
  phone: string;
  is_active: boolean;
  rider_url: string;
  whatsapp_url: string;
  last_lat?: number | null;
  last_lng?: number | null;
  last_location_at?: string | null;
}

export interface SettlementRow {
  id: string;
  transaction_id: string;
  utr_reference?: string;
  customer_name: string;
  customer_phone?: string;
  plan_name: string;
  amount_inr: number;
  status: string;
  payment_mode: string;
  created_at: string;
  paid_at?: string;
}

export interface ProviderProfileDetails {
  id: string;
  display_name: string;
  description?: string;
  cover_path?: string | null;
  logo_path?: string | null;
  public_phone?: string | null;
  public_email?: string | null;
  address_line1?: string | null;
  locality?: string | null;
  city?: string | null;
  supports_pickup?: boolean;
  supports_delivery?: boolean;
  status?: string;
}

export function formatInr(amountInr: number): string {
  return `₹${Math.round(amountInr || 0).toLocaleString('en-IN')}`;
}

export function formatShortDate(iso?: string | null): string {
  if (!iso) return '—';
  const dt = new Date(iso);
  if (Number.isNaN(dt.getTime())) return String(iso);
  return dt.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}
