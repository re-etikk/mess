-- ==============================================================================
-- 001_initial_schema.sql
-- SMART TIFFIN SUBSCRIPTION & DELIVERY PLATFORM
-- Production-ready PostgreSQL schema with RLS, Constraints, and Stored Procedures
-- ==============================================================================

-- Enable UUID and Cryptographic extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Custom Enums
CREATE TYPE user_role AS ENUM (
    'customer',
    'provider',
    'delivery_partner',
    'admin',
    'support'
);

CREATE TYPE plan_type AS ENUM (
    'fixed_period',
    'meal_based',
    'daily_pay_as_you_eat'
);

CREATE TYPE subscription_status AS ENUM (
    'active',
    'paused',
    'expired',
    'cancelled'
);

CREATE TYPE fulfillment_type AS ENUM (
    'pickup',
    'delivery'
);

CREATE TYPE booking_status AS ENUM (
    'confirmed',
    'redeemed',
    'out_for_delivery',
    'delivered',
    'cancelled',
    'no_show'
);

CREATE TYPE delivery_status AS ENUM (
    'pending_assignment',
    'offered',
    'accepted',
    'arrived_at_kitchen',
    'picked_up',
    'arrived_at_customer',
    'delivered',
    'cancelled',
    'failed'
);

CREATE TYPE payment_status AS ENUM (
    'created',
    'pending',
    'captured',
    'failed',
    'refunded'
);

CREATE TYPE dietary_type AS ENUM (
    'veg',
    'non_veg',
    'jain',
    'vegan',
    'egg'
);

CREATE TYPE ticket_status AS ENUM (
    'open',
    'investigating',
    'resolved',
    'closed'
);

-- ==============================================================================
-- 1. USERS, PROFILES, AND ROLES
-- ==============================================================================

CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id UUID UNIQUE, -- Foreign key to auth.users if Supabase Auth is enabled
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    avatar_url TEXT,
    preferred_language VARCHAR(10) DEFAULT 'en',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS role_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role user_role NOT NULL,
    assigned_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, role)
);

CREATE TABLE IF NOT EXISTS customer_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    label VARCHAR(50) DEFAULT 'Home', -- e.g. Hostel Room, PG, Office, Home
    flat_room_number TEXT NOT NULL,
    building_name TEXT NOT NULL,
    street_address TEXT NOT NULL,
    landmark TEXT,
    area TEXT NOT NULL,
    city TEXT NOT NULL DEFAULT 'Bengaluru',
    state TEXT NOT NULL DEFAULT 'Karnataka',
    pincode VARCHAR(10) NOT NULL,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    delivery_instructions TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 2. FOOD PROVIDERS AND KITCHENS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS provider_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    business_name TEXT NOT NULL,
    tagline TEXT,
    description TEXT,
    business_type VARCHAR(50) DEFAULT 'mess', -- 'mess', 'restaurant', 'home_tiffin', 'caterer'
    fssai_license_number VARCHAR(50),
    fssai_verified BOOLEAN NOT NULL DEFAULT FALSE,
    contact_phone TEXT NOT NULL,
    contact_email TEXT NOT NULL,
    dietary_types dietary_type[] NOT NULL DEFAULT '{veg}',
    cuisines TEXT[] NOT NULL DEFAULT '{North Indian, South Indian}',
    address TEXT NOT NULL,
    area TEXT NOT NULL,
    city TEXT NOT NULL DEFAULT 'Bengaluru',
    pincode VARCHAR(10) NOT NULL,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    banner_image_url TEXT,
    logo_image_url TEXT,
    rating NUMERIC(3, 2) NOT NULL DEFAULT 4.5,
    total_reviews INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_accepting_orders BOOLEAN NOT NULL DEFAULT TRUE,
    payout_account_added BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS provider_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL, -- 'fssai_certificate', 'gst_certificate', 'pan_card', 'bank_proof'
    document_url TEXT NOT NULL,
    verification_status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'verified', 'rejected'
    verified_by UUID REFERENCES profiles(id),
    verification_notes TEXT,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS provider_service_areas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
    pincode VARCHAR(10) NOT NULL,
    area_name TEXT NOT NULL,
    max_delivery_distance_km NUMERIC(5, 2) NOT NULL DEFAULT 5.0,
    delivery_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    base_delivery_fee_inr NUMERIC(10, 2) NOT NULL DEFAULT 30.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(provider_id, pincode)
);

CREATE TABLE IF NOT EXISTS meal_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
    slot_name VARCHAR(50) NOT NULL, -- 'Breakfast', 'Lunch', 'Dinner'
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    booking_cutoff_time TIME NOT NULL, -- Customer must book before this time on the same day or previous day
    max_daily_capacity INTEGER DEFAULT 200,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(provider_id, slot_name)
);

CREATE TABLE IF NOT EXISTS menus (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL DEFAULT 'Standard Daily Menu',
    description TEXT,
    day_of_week INTEGER, -- 0 = Sunday, 1 = Monday ... 6 = Saturday, NULL = Everyday
    meal_slot_id UUID REFERENCES meal_slots(id) ON DELETE SET NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS menu_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_id UUID NOT NULL REFERENCES menus(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    dietary_type dietary_type NOT NULL DEFAULT 'veg',
    category VARCHAR(50) NOT NULL DEFAULT 'Main Course', -- 'Bread/Roti', 'Curry/Dal', 'Rice', 'Sweet', 'Side'
    is_optional BOOLEAN NOT NULL DEFAULT FALSE,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    calories INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 3. SUBSCRIPTIONS & ENTITLEMENTS (3 DISTINCT MODELS)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    plan_type plan_type NOT NULL, -- 'fixed_period', 'meal_based', 'daily_pay_as_you_eat'
    duration_days INTEGER NOT NULL DEFAULT 30, -- 1, 30, 90, 180, 365
    duration_months INTEGER DEFAULT 1, -- 1, 3, 6, 12
    total_meals INTEGER, -- NULL for fixed_period; e.g. 30, 60 for meal_based; 1 for daily
    price_inr NUMERIC(10, 2) NOT NULL,
    original_price_inr NUMERIC(10, 2), -- for showing discount badges
    discount_percent NUMERIC(5, 2) DEFAULT 0.00,
    allowed_meal_slots TEXT[] NOT NULL DEFAULT '{"Lunch", "Dinner"}',
    daily_meal_limit INTEGER NOT NULL DEFAULT 2, -- e.g. Max 1 lunch + 1 dinner per day
    weekend_service_included BOOLEAN NOT NULL DEFAULT TRUE,
    delivery_eligible BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE RESTRICT,
    status subscription_status NOT NULL DEFAULT 'active',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_meals_credited INTEGER, -- e.g. 30 for meal_based
    remaining_meals INTEGER, -- strictly non-negative, decremented on redemption
    pause_days_used INTEGER NOT NULL DEFAULT 0,
    max_pause_days_allowed INTEGER NOT NULL DEFAULT 7,
    auto_renew BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_remaining_meals_non_negative CHECK (remaining_meals IS NULL OR remaining_meals >= 0)
);

-- ==============================================================================
-- 4. BOOKINGS, ORDERS & MEAL REDEMPTION
-- ==============================================================================

CREATE TABLE IF NOT EXISTS bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE RESTRICT, -- NULL for single meal pay-as-you-eat
    provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE RESTRICT,
    meal_slot_id UUID NOT NULL REFERENCES meal_slots(id) ON DELETE RESTRICT,
    booking_date DATE NOT NULL,
    fulfillment_type fulfillment_type NOT NULL DEFAULT 'pickup',
    delivery_address_id UUID REFERENCES customer_addresses(id),
    status booking_status NOT NULL DEFAULT 'confirmed',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Prevent duplicate active booking for the same customer, meal slot, and date
    CONSTRAINT uq_customer_slot_date UNIQUE (customer_id, meal_slot_id, booking_date)
);

CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number TEXT UNIQUE NOT NULL,
    customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE RESTRICT,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    item_type VARCHAR(50) NOT NULL, -- 'subscription_purchase', 'daily_meal', 'delivery_fee'
    subtotal_inr NUMERIC(10, 2) NOT NULL,
    discount_inr NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    delivery_fee_inr NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    platform_fee_inr NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    tax_inr NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    total_amount_inr NUMERIC(10, 2) NOT NULL,
    payment_status payment_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cryptographically secure, single-use, 5-minute QR redemption tokens
CREATE TABLE IF NOT EXISTS redemption_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE, -- SHA256 hash of signed token payload
    nonce TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT FALSE,
    used_at TIMESTAMPTZ,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auditable record of every successful meal redemption
CREATE TABLE IF NOT EXISTS meal_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE RESTRICT,
    token_id UUID REFERENCES redemption_tokens(id),
    redemption_method VARCHAR(30) NOT NULL DEFAULT 'qr_scan', -- 'qr_scan', 'delivery_otp', 'manual_override'
    verified_by UUID NOT NULL REFERENCES profiles(id), -- Provider staff or delivery partner
    redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    client_metadata JSONB DEFAULT '{}'::jsonb
);

-- ==============================================================================
-- 5. DELIVERY SYSTEM & PARTNERS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS delivery_partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    vehicle_type VARCHAR(30) NOT NULL DEFAULT 'bicycle', -- 'bicycle', 'motorcycle', 'ev_scooter'
    vehicle_registration_number TEXT,
    driving_license_number TEXT,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_available BOOLEAN NOT NULL DEFAULT FALSE,
    current_latitude NUMERIC(10, 7),
    current_longitude NUMERIC(10, 7),
    last_location_updated_at TIMESTAMPTZ,
    total_deliveries_completed INTEGER NOT NULL DEFAULT 0,
    rating NUMERIC(3, 2) NOT NULL DEFAULT 5.0,
    bank_account_number TEXT,
    bank_ifsc_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS delivery_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE RESTRICT,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    delivery_partner_id UUID REFERENCES delivery_partners(id) ON DELETE SET NULL,
    status delivery_status NOT NULL DEFAULT 'pending_assignment',
    delivery_otp VARCHAR(6) NOT NULL, -- 4 or 6 digit secure OTP given by customer upon delivery
    otp_failed_attempts INTEGER NOT NULL DEFAULT 0,
    pickup_address TEXT NOT NULL,
    delivery_address TEXT NOT NULL,
    delivery_contact_phone TEXT NOT NULL,
    distance_km NUMERIC(5, 2) NOT NULL DEFAULT 2.5,
    estimated_payout_inr NUMERIC(10, 2) NOT NULL DEFAULT 25.00,
    assigned_at TIMESTAMPTZ,
    picked_up_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS delivery_status_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES delivery_assignments(id) ON DELETE CASCADE,
    status delivery_status NOT NULL,
    actor_id UUID REFERENCES profiles(id),
    actor_role user_role,
    notes TEXT,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 6. PAYMENTS, COMMISSIONS, LEDGER & SETTLEMENTS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    gateway_provider VARCHAR(30) NOT NULL DEFAULT 'razorpay', -- 'razorpay', 'cashfree', 'mock'
    gateway_order_id TEXT NOT NULL,
    gateway_payment_id TEXT UNIQUE,
    idempotency_key TEXT UNIQUE NOT NULL,
    amount_inr NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'INR',
    status payment_status NOT NULL DEFAULT 'created',
    payment_method VARCHAR(50), -- 'upi', 'netbanking', 'card', 'wallet'
    gateway_signature TEXT,
    raw_webhook_payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_transaction_id UUID NOT NULL REFERENCES payment_transactions(id) ON DELETE RESTRICT,
    amount_inr NUMERIC(10, 2) NOT NULL,
    reason TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'initiated', -- 'initiated', 'processed', 'failed'
    gateway_refund_id TEXT,
    requested_by UUID NOT NULL REFERENCES profiles(id),
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Commission configuration rules per provider or launch cohort
CREATE TABLE IF NOT EXISTS commission_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES provider_profiles(id) ON DELETE CASCADE, -- NULL means default global platform rule
    commission_percent NUMERIC(5, 2) NOT NULL DEFAULT 3.50, -- 0% for promotional period, 2-5% standard
    is_promotional BOOLEAN NOT NULL DEFAULT FALSE,
    promotion_name TEXT,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ,
    agreed_by_provider BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Immutable financial ledger of commission splits
CREATE TABLE IF NOT EXISTS commission_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_transaction_id UUID NOT NULL REFERENCES payment_transactions(id) ON DELETE RESTRICT,
    provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE RESTRICT,
    gross_amount_inr NUMERIC(10, 2) NOT NULL,
    commission_percent NUMERIC(5, 2) NOT NULL,
    platform_commission_inr NUMERIC(10, 2) NOT NULL,
    delivery_fee_collected_inr NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    net_provider_share_inr NUMERIC(10, 2) NOT NULL,
    is_promotional_zero_fee BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Provider periodic settlement batch records
CREATE TABLE IF NOT EXISTS provider_settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    settlement_reference TEXT UNIQUE NOT NULL,
    provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE RESTRICT,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    total_orders INTEGER NOT NULL DEFAULT 0,
    gross_sales_inr NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    platform_commission_inr NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    refunds_deducted_inr NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    net_payable_inr NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(30) NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'settled', 'failed'
    utr_number TEXT,
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Delivery partner earnings & payouts
CREATE TABLE IF NOT EXISTS delivery_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payout_reference TEXT UNIQUE NOT NULL,
    delivery_partner_id UUID NOT NULL REFERENCES delivery_partners(id) ON DELETE RESTRICT,
    assignment_id UUID NOT NULL REFERENCES delivery_assignments(id) ON DELETE RESTRICT,
    payout_amount_inr NUMERIC(10, 2) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending', -- 'pending', 'paid'
    utr_number TEXT,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 7. SUPPORT TICKETS, NOTIFICATIONS & AUDIT LOGS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_number TEXT UNIQUE NOT NULL,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    provider_id UUID REFERENCES provider_profiles(id) ON DELETE SET NULL,
    subject TEXT NOT NULL,
    category VARCHAR(50) NOT NULL DEFAULT 'meal_quality', -- 'delivery_delay', 'missing_meal', 'billing', 'hygiene'
    description TEXT NOT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'medium', -- 'low', 'medium', 'high', 'urgent'
    status ticket_status NOT NULL DEFAULT 'open',
    assigned_to UUID REFERENCES profiles(id),
    resolution_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'system', -- 'booking_confirmed', 'meal_redeemed', 'delivery_update', 'payment'
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    actor_role user_role,
    action TEXT NOT NULL,
    target_entity TEXT NOT NULL,
    target_id UUID,
    changes_json JSONB,
    ip_address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 8. INDEXES FOR HIGH-PERFORMANCE QUERYING
-- ==============================================================================

CREATE INDEX IF NOT EXISTS idx_provider_city_area ON provider_profiles(city, area);
CREATE INDEX IF NOT EXISTS idx_provider_active ON provider_profiles(is_active, is_accepting_orders);
CREATE INDEX IF NOT EXISTS idx_subscriptions_customer ON subscriptions(customer_id, status);
CREATE INDEX IF NOT EXISTS idx_bookings_date_slot ON bookings(booking_date, meal_slot_id, provider_id);
CREATE INDEX IF NOT EXISTS idx_redemption_tokens_hash ON redemption_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_delivery_assignments_partner ON delivery_assignments(delivery_partner_id, status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_order ON payment_transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_commission_ledger_provider ON commission_ledger(provider_id);

-- ==============================================================================
-- 9. ATOMIC QR REDEMPTION STORED PROCEDURE
-- Validates token, checks expiry, locks row, checks provider & subscription,
-- decrements meal ledger, prevents race conditions, and marks redeemed.
-- ==============================================================================

CREATE OR REPLACE FUNCTION redeem_meal_token(
    p_token_hash TEXT,
    p_provider_id UUID,
    p_verifier_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_token RECORD;
    v_booking RECORD;
    v_subscription RECORD;
    v_redemption_id UUID;
    v_remaining_meals INTEGER;
BEGIN
    -- 1. Find and lock the redemption token row FOR UPDATE
    SELECT * INTO v_token
    FROM redemption_tokens
    WHERE token_hash = p_token_hash
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error_code', 'INVALID_TOKEN',
            'message', 'The QR code presented is invalid or does not exist.'
        );
    END IF;

    -- 2. Check if already used
    IF v_token.is_used THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error_code', 'TOKEN_ALREADY_USED',
            'message', 'This QR code was already redeemed at ' || to_char(v_token.used_at, 'HH12:MI AM') || '.'
        );
    END IF;

    -- 3. Check if expired (strictly 5-minute validity window)
    IF v_token.expires_at < NOW() THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error_code', 'TOKEN_EXPIRED',
            'message', 'This QR code has expired. Please refresh the QR code on your customer app.'
        );
    END IF;

    -- 4. Retrieve and lock the associated booking
    SELECT * INTO v_booking
    FROM bookings
    WHERE id = v_token.booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error_code', 'BOOKING_NOT_FOUND',
            'message', 'Associated meal booking not found.'
        );
    END IF;

    -- 5. Verify provider match: Ensure provider scanning is the provider for this booking
    IF v_booking.provider_id <> p_provider_id THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error_code', 'WRONG_PROVIDER',
            'message', 'This QR code is for a different kitchen/provider.'
        );
    END IF;

    -- 6. Verify booking status
    IF v_booking.status = 'redeemed' THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error_code', 'MEAL_ALREADY_REDEEMED',
            'message', 'This meal was already redeemed.'
        );
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error_code', 'BOOKING_CANCELLED',
            'message', 'This meal booking was cancelled.'
        );
    END IF;

    -- 7. Check subscription balance if booking is under a subscription
    IF v_booking.subscription_id IS NOT NULL THEN
        SELECT * INTO v_subscription
        FROM subscriptions
        WHERE id = v_booking.subscription_id
        FOR UPDATE;

        IF NOT FOUND OR v_subscription.status <> 'active' THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'error_code', 'SUBSCRIPTION_INACTIVE',
                'message', 'The customer subscription is inactive or expired.'
            );
        END IF;

        -- If meal-based plan, check remaining balance
        IF v_subscription.remaining_meals IS NOT NULL THEN
            IF v_subscription.remaining_meals <= 0 THEN
                RETURN jsonb_build_object(
                    'success', FALSE,
                    'error_code', 'ZERO_BALANCE',
                    'message', 'No remaining meals left in this subscription.'
                );
            END IF;

            -- Deduct exactly one meal
            UPDATE subscriptions
            SET remaining_meals = remaining_meals - 1,
                updated_at = NOW()
            WHERE id = v_subscription.id
            RETURNING remaining_meals INTO v_remaining_meals;
        END IF;
    END IF;

    -- 8. Mark token as used
    UPDATE redemption_tokens
    SET is_used = TRUE,
        used_at = NOW()
    WHERE id = v_token.id;

    -- 9. Mark booking as redeemed
    UPDATE bookings
    SET status = 'redeemed',
        updated_at = NOW()
    WHERE id = v_booking.id;

    -- 10. Record immutable meal redemption event
    INSERT INTO meal_redemptions (
        booking_id,
        customer_id,
        provider_id,
        token_id,
        redemption_method,
        verified_by,
        redeemed_at
    ) VALUES (
        v_booking.id,
        v_booking.customer_id,
        p_provider_id,
        v_token.id,
        'qr_scan',
        p_verifier_user_id,
        NOW()
    ) RETURNING id INTO v_redemption_id;

    -- 11. Create customer notification
    INSERT INTO notifications (
        user_id,
        title,
        message,
        type,
        metadata
    ) VALUES (
        v_booking.customer_id,
        'Meal Redeemed Successfully!',
        'Your meal has been marked as redeemed. Enjoy your food!',
        'meal_redeemed',
        jsonb_build_object('booking_id', v_booking.id, 'redemption_id', v_redemption_id)
    );

    -- 12. Create audit log
    INSERT INTO audit_logs (
        actor_id,
        actor_role,
        action,
        target_entity,
        target_id,
        changes_json
    ) VALUES (
        p_verifier_user_id,
        'provider',
        'REDEEM_MEAL_QR',
        'bookings',
        v_booking.id,
        jsonb_build_object(
            'token_id', v_token.id,
            'redemption_id', v_redemption_id,
            'remaining_meals', v_remaining_meals
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'redemption_id', v_redemption_id,
        'booking_id', v_booking.id,
        'customer_id', v_booking.customer_id,
        'remaining_meals', v_remaining_meals,
        'redeemed_at', NOW()
    );
END;
$$;

-- ==============================================================================
-- 10. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE provider_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;

-- Profiles: Anyone authenticated can read their own profile; admins can read all
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = auth_user_id);

CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = auth_user_id);

-- Addresses: Customers can manage their own addresses
CREATE POLICY "Customers can manage own addresses" ON customer_addresses
    FOR ALL USING (customer_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid()));

-- Provider Profiles: Anyone can view active providers (public marketplace)
CREATE POLICY "Anyone can view active providers" ON provider_profiles
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Providers can update own profile" ON provider_profiles
    FOR UPDATE USING (user_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid()));

-- Subscription Plans: Publicly visible
CREATE POLICY "Anyone can view active plans" ON subscription_plans
    FOR SELECT USING (is_active = TRUE);

-- Subscriptions: Customers can view their own, providers can view their subscribers
CREATE POLICY "Customers can view own subscriptions" ON subscriptions
    FOR SELECT USING (
        customer_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid()) OR
        provider_id IN (SELECT id FROM provider_profiles WHERE user_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid()))
    );

-- Bookings: Customer and provider can view
CREATE POLICY "Customer and provider can view bookings" ON bookings
    FOR SELECT USING (
        customer_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid()) OR
        provider_id IN (SELECT id FROM provider_profiles WHERE user_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid()))
    );

-- Notifications: User can view and update own notifications
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (user_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid()));

CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (user_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid()));
