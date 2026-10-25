# 🚀 Deployment & Production Operations Guide

This guide details the step-by-step deployment and operational configuration for launching the **Smart Tiffin Subscription & Delivery Platform** in the Indian market.

---

## 1. Supabase Database & Auth Deployment

1. **Create Supabase Project:**
   - Log into [Supabase Dashboard](https://supabase.com).
   - Create a new project in the **AWS Mumbai (ap-south-1)** region for optimal latency across Indian metros.
2. **Apply Database Migrations:**
   - In your local terminal or via the Supabase SQL Editor, run:
     ```bash
     supabase db push
     ```
     Or execute `supabase/migrations/001_initial_schema.sql` in the Supabase SQL editor.
   - Verify that all 25+ tables, custom ENUMs, Row Level Security (RLS) policies, and the `redeem_meal_token` stored procedure are created.
3. **Seed Initial Locations & Verified Kitchens:**
   - Execute `supabase/seed.sql` to populate initial Bengaluru provider profiles, meal slots, and subscription plans.
4. **Retrieve API Keys:**
   - Copy `Project URL`, `anon public key`, and `service_role secret key` into your environment variables.

---

## 2. Next.js Web Platform Deployment (Vercel / AWS Amplify)

1. **Deploy to Vercel:**
   - Connect your GitHub repository to Vercel.
   - Set **Root Directory** to `apps/web`.
   - Set Framework Preset to **Next.js**.
2. **Configure Environment Variables in Vercel:**
   ```env
   NEXT_PUBLIC_BRAND_NAME="MESS"
   NEXT_PUBLIC_BRAND_TAGLINE="Your Meals. Your Choice."
   NEXT_PUBLIC_DEFAULT_CITY="Bengaluru"
   NEXT_PUBLIC_CURRENCY_SYMBOL="₹"
   NEXT_PUBLIC_TIMEZONE="Asia/Kolkata"
   NEXT_PUBLIC_SUPABASE_URL="https://your-project.supabase.co"
   NEXT_PUBLIC_SUPABASE_ANON_KEY="your-anon-key"
   SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
   QR_HMAC_SECRET="your-32-character-high-entropy-secret"
   PAYMENT_GATEWAY_PROVIDER="razorpay"
   RAZORPAY_KEY_ID="rzp_live_yourKeyId"
   RAZORPAY_KEY_SECRET="yourRazorpayLiveSecret"
   RAZORPAY_WEBHOOK_SECRET="yourRazorpayWebhookSecret"
   DEFAULT_PLATFORM_COMMISSION_PERCENT=3.5
   PROMOTIONAL_PERIOD_MONTHS=2
   DEFAULT_BASE_DELIVERY_FEE_INR=30
   DEFAULT_PER_KM_DELIVERY_FEE_INR=10
   DEFAULT_RIDER_PAYOUT_PERCENT=85
   ```
3. **Verify Deployment:**
   - Check public routes: `/` (Discovery), `/provider/[id]` (Plan details), `/customer/dashboard` (Live QR), `/provider/portal` (Scanner), `/rider/portal` (Fleet), `/admin/dashboard` (Admin).

---

## 3. Three Flutter Android Mobile Apps Deployment

The platform provides three dedicated native Android applications:

### App 1: Customer App (`apps/mobile_customer`)
```bash
cd apps/mobile_customer
flutter pub get
flutter test
# Generate Android APK:
flutter build apk --debug  # or flutter build apk --release
# Generated artifact:
# apps/mobile_customer/build/app/outputs/flutter-apk/app-debug.apk
```

### App 2: Kitchen Partner / Provider App (`apps/mobile_provider`)
```bash
cd apps/mobile_provider
flutter pub get
flutter test
# Generate Android APK:
flutter build apk --debug  # or flutter build apk --release
# Generated artifact:
# apps/mobile_provider/build/app/outputs/flutter-apk/app-debug.apk
```

### App 3: Delivery Fleet Partner App (`apps/mobile_delivery`)
```bash
cd apps/mobile_delivery
flutter pub get
flutter test
# Generate Android APK:
flutter build apk --debug  # or flutter build apk --release
# Generated artifact:
# apps/mobile_delivery/build/app/outputs/flutter-apk/app-debug.apk
```

---

## 4. Payment Gateway & Webhook Integration (Razorpay / Cashfree)

1. **Merchant Onboarding & KYC:**
   - Complete business KYC on Razorpay / Cashfree as a Registered Marketplace / Aggregator.
   - Configure split settlement rules if using Razorpay Route.
2. **Webhook Registration:**
   - Add webhook endpoint URL: `https://yourdomain.com/api/payments/webhook`
   - Enable events:
     - `payment.captured`
     - `payment.failed`
     - `order.paid`
     - `refund.processed`
   - Set secret matching `RAZORPAY_WEBHOOK_SECRET`.

---

## 5. FSSAI & Food Regulatory Compliance Checklist

- [ ] Every food provider onboarding requires a valid 14-digit FSSAI license number.
- [ ] Provider document uploads verified by admin before activating `is_active = TRUE`.
- [ ] Display FSSAI license badge on provider cards and customer checkout screens.
- [ ] Enforce order cutoffs (11:00 AM lunch / 6:00 PM dinner) to ensure fresh food preparation without food wastage.
- [ ] Temperature-controlled or insulated delivery bags required for all registered delivery partners.
