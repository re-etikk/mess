// ==============================================================================
// SHARED DOMAIN TYPES
// ==============================================================================

export type UserRole = 'customer' | 'provider' | 'delivery_partner' | 'admin' | 'support';

export type PlanType = 'fixed_period' | 'meal_based' | 'daily_pay_as_you_eat';

export type SubscriptionStatus = 'active' | 'paused' | 'expired' | 'cancelled' | 'refunded';

export type FulfillmentType = 'pickup' | 'delivery';

export type BookingStatus = 'confirmed' | 'redeemed' | 'out_for_delivery' | 'delivered' | 'cancelled' | 'no_show';

export type DeliveryStatus =
  | 'pending_assignment'
  | 'offered'
  | 'accepted'
  | 'arrived_at_kitchen'
  | 'picked_up'
  | 'arrived_at_customer'
  | 'delivered'
  | 'cancelled'
  | 'failed';

export type PaymentStatus = 'created' | 'pending' | 'captured' | 'failed' | 'refunded';

export type DietaryType = 'veg' | 'non_veg' | 'jain' | 'vegan' | 'egg';

export interface Profile {
  id: string;
  auth_user_id?: string;
  full_name: string;
  email: string;
  phone?: string;
  avatar_url?: string;
  preferred_language: string;
  created_at: string;
}

export interface CustomerAddress {
  id: string;
  customer_id: string;
  label: string;
  flat_room_number: string;
  building_name: string;
  street_address: string;
  landmark?: string;
  area: string;
  city: string;
  state: string;
  pincode: string;
  latitude?: number;
  longitude?: number;
  is_default: boolean;
  delivery_instructions?: string;
}

export interface MealSlot {
  id: string;
  provider_id: string;
  slot_name: string; // 'Lunch', 'Dinner', 'Breakfast'
  start_time: string; // '12:00:00'
  end_time: string;   // '15:00:00'
  booking_cutoff_time: string; // '10:30:00'
  max_daily_capacity?: number;
  is_active: boolean;
}

export interface MenuItem {
  id: string;
  menu_id: string;
  name: string;
  description?: string;
  dietary_type: DietaryType;
  category: string;
  is_available: boolean;
  calories?: number;
}

export interface SubscriptionPlan {
  id: string;
  provider_id: string;
  name: string;
  description: string;
  plan_type: PlanType;
  duration_days: number;
  duration_months?: number;
  total_meals?: number | null;
  price_inr: number;
  original_price_inr?: number;
  discount_percent?: number;
  allowed_meal_slots: string[];
  daily_meal_limit: number;
  delivery_eligible: boolean;
  is_active: boolean;
}

export interface ProviderProfile {
  id: string;
  user_id: string;
  business_name: string;
  tagline?: string;
  description?: string;
  business_type: string;
  fssai_license_number?: string;
  fssai_verified: boolean;
  contact_phone: string;
  contact_email: string;
  dietary_types: DietaryType[];
  cuisines: string[];
  address: string;
  area: string;
  city: string;
  pincode: string;
  banner_image_url?: string;
  logo_image_url?: string;
  rating: number;
  total_reviews: number;
  is_active: boolean;
  is_accepting_orders: boolean;
  payout_account_added: boolean;
  service_areas?: {
    pincode: string;
    area_name: string;
    max_delivery_distance_km: number;
    base_delivery_fee_inr: number;
    delivery_enabled?: boolean;
  }[];
  meal_slots?: MealSlot[];
  plans?: SubscriptionPlan[];
}

export interface Subscription {
  id: string;
  customer_id: string;
  provider_id: string;
  plan_id: string;
  status: SubscriptionStatus;
  start_date: string;
  end_date: string;
  total_meals_credited?: number;
  remaining_meals?: number;
  pause_days_used: number;
  max_pause_days_allowed: number;
  auto_renew: boolean;
  plan?: SubscriptionPlan;
  provider?: ProviderProfile;
}

export interface Booking {
  id: string;
  customer_id: string;
  subscription_id?: string;
  provider_id: string;
  meal_slot_id: string;
  booking_date: string;
  fulfillment_type: FulfillmentType;
  delivery_address_id?: string;
  status: BookingStatus;
  notes?: string;
  slot?: MealSlot;
  provider?: ProviderProfile;
  address?: CustomerAddress;
  subscription?: Subscription;
}

export interface RedemptionTokenPayload {
  booking_id: string;
  customer_id: string;
  provider_id: string;
  meal_slot_id: string;
  booking_date: string;
  nonce: string;
  expires_at: number; // Unix epoch ms
}

export interface QRVerificationResult {
  success: boolean;
  error_code?: string;
  message: string;
  redemption_id?: string;
  customer_name?: string;
  meal_slot?: string;
  remaining_meals?: number;
  redeemed_at?: string;
}

export interface DeliveryAssignment {
  id: string;
  booking_id: string;
  order_id?: string;
  delivery_partner_id?: string;
  status: DeliveryStatus;
  delivery_otp: string;
  pickup_address: string;
  delivery_address: string;
  delivery_contact_phone: string;
  distance_km: number;
  estimated_payout_inr: number;
  assigned_at?: string;
  picked_up_at?: string;
  delivered_at?: string;
  booking?: Booking;
}

export interface CommissionLedgerEntry {
  id: string;
  payment_transaction_id: string;
  provider_id: string;
  gross_amount_inr: number;
  commission_percent: number;
  platform_commission_inr: number;
  net_provider_share_inr: number;
  is_promotional_zero_fee: boolean;
  created_at: string;
}


export interface MenuExtraItem {
  name: string;
  price: number;
  limit?: number;
}

export interface MessMenu {
  id: string;
  provider_id: string;
  day_of_week: string;
  slot: string;
  items_included: string[];
  items_extra: MenuExtraItem[];
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface MessAddon {
  id: string;
  provider_id: string;
  plan_id?: string;
  item_name: string;
  price_paise: number;
  category: string;
  is_available: boolean;
  created_at?: string;
}

export interface PlatformInvoice {
  id: string;
  provider_id: string;
  period_start: string;
  period_end: string;
  total_scans: number;
  total_due_paise: number;
  razorpay_invoice_id?: string;
  razorpay_payment_id?: string;
  status: 'pending' | 'paid' | 'failed' | 'waived';
  paid_at?: string;
  created_at: string;
}

export interface MealRedemptionRecord {
  id: string;
  user_id: string;
  provider_id: string;
  subscription_id?: string;
  date: string;
  slot: string;
  amount_extra_paise: number;
  extra_items: MenuExtraItem[];
  remarks?: string;
  redeemed_at: string;
}


export interface MessReview {
  id: string;
  provider_id: string;
  customer_id: string;
  customer_name?: string;
  rating: number; // 1 to 5
  review_text?: string;
  food_quality_score?: number;
  hygiene_score?: number;
  tags?: string[];
  created_at: string;
}

export interface PromoCode {
  id: string;
  code: string;
  provider_id?: string;
  title: string;
  description?: string;
  discount_percent?: number;
  flat_discount_paise?: number;
  min_order_paise: number;
  max_discount_paise?: number;
  is_active: boolean;
}

export interface Announcement {
  id: string;
  provider_id?: string;
  title: string;
  body: string;
  badge_text?: string;
  action_url?: string;
  is_featured: boolean;
  is_active: boolean;
  created_at: string;
}

export interface CustomerNotification {
  id: string;
  customer_id: string;
  title: string;
  message: string;
  notification_type: 'meal_redemption' | 'plan_expiry' | 'menu_update' | 'billing' | 'offer' | 'system';
  is_read: boolean;
  created_at: string;
}
