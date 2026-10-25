# MESS Flutter Customer App Starter

This is a **customer/student app starter** for MESS. It includes connected navigation, screen interactions, a real camera QR scanner using `mobile_scanner`, local demo state, subscription/menu models, and a handoff prompt for Antigravity.

## Important status

This is a **local demo prototype**, not a production app yet.

- Manual sign-in/register currently creates a local demo session.
- Google sign-in UI is present but OAuth is not connected.
- Plan and daily-meal checkout simulate local state only; no real money is charged.
- The included `DemoMessRepository` keeps data in memory and resets when the app restarts.
- QR redemption only accepts a demo payload and cannot verify a cryptographic signature. It is **not secure for production**.
- Prices and initial active subscription are illustrative fixtures. Replace them with provider-supplied records before launch.
- The provider app / provider QR generator and website are not included as executable apps in this customer starter; the Antigravity prompt directs the agent to wire the customer app to the shared backend and build the related surfaces.

Do not publish this demo as a live payment or meal-attendance product.

## Files

- `lib/main.dart` — Flutter entry point.
- `lib/mess_app.dart` — app theme and signed-in/signed-out flow.
- `lib/core/models/` — provider, plan, meal-slot, subscription, entitlement and add-on models.
- `lib/core/repositories/` — repository contract and local demo adapter.
- `lib/core/state/app_state.dart` — local demo app state.
- `lib/features/auth/` — login, registration and forgot-password screens.
- `lib/features/home/` — customer dashboard and bottom navigation.
- `lib/features/search/` — food/mess search and filters.
- `lib/features/mess/` — provider details, daily menu and extra portions.
- `lib/features/plans/` — fixed-period, meal-tracker and daily-meal plans.
- `lib/features/checkout/` — explicitly labelled test checkout only.
- `lib/features/scan/` — customer scans the provider's QR, not the other way around.
- `lib/features/history/` and `lib/features/profile/` — records, account details and draft legal pages.
- `prompts/ANTIGRAVITY_MASTER_PROMPT.md` — complete implementation and integration prompt.
- `prompts/LOOP_CONTINUE_PROMPT.md` — iterative build/test/fix instruction.
- `prompts/RELEASE_AUDIT_PROMPT.md` — final audit prompt.
- `assets/branding/mess_logo_reference.png` — visual logo reference. The live Flutter header uses a lightweight vector-like Flutter widget so it remains sharp at small sizes.

## Run locally

Flutter SDK is required. This archive does not include generated Android/iOS platform folders because the app is intended to be merged into your existing Flutter repository.

1. Create a shell project if you want to run it separately:

   ```bash
   flutter create mess_customer_app
   ```

2. Copy the `lib/` directory and `assets/` directory from this starter into that project.
3. Merge the dependencies and asset declaration from this `pubspec.yaml` into your project's existing `pubspec.yaml`. Do not overwrite existing project configuration blindly.
4. Run:

   ```bash
   flutter pub get
   flutter analyze
   flutter test
   flutter run
   ```

The QR scanner uses `mobile_scanner: ^7.4.2`, whose package page documents Android/iOS camera scanning and current setup guidance: https://pub.dev/packages/mobile_scanner

For iOS, add `NSCameraUsageDescription` to `ios/Runner/Info.plist`, for example:

```xml
<key>NSCameraUsageDescription</key>
<string>MESS uses the camera to scan the QR displayed at your selected mess.</string>
```

Confirm camera permission and build settings on the target Android/iOS project, then test on a physical device. A simulator may not provide a usable camera.

## Demo flow

1. Enter any syntactically valid email or phone and a password of at least six characters to open the demo home.
2. The starter seeds a demo active Radhe Mess meal-tracker plan so the active-plan dashboard can be reviewed.
3. Use Profile → **Demo preview tools** to switch between the active-plan and no-subscription dashboard states. Remove these tools before production.
4. Search for a mess or food, open provider details, select a plan, and use the explicitly labelled demo checkout. This changes local demo state only.
5. Open the scanner during an eligible meal slot and use a `MESS_DEMO|provider-id|YYYY-MM-DD|local-demo-only` QR. The demo button creates the current code locally, but the meal can still fail if the current time is outside the provider's configured serving slot or there is no valid entitlement.

## Mandatory production replacements

1. Replace `DemoMessRepository` with a server-backed implementation. Keep the `MessRepository` interface as the seam.
2. Replace `signInDemo` with real authentication, including Google OAuth configured in the identity provider. Never treat the current demo sign-in as secure.
3. Verify payment through signed gateway webhooks/server-side status checks before activating a plan or a daily meal entitlement.
4. Generate provider-specific, date-bound signed QR payloads in the provider app/backend. Server validates token, provider, date, customer, slot, eligibility and duplicate redemptions atomically.
5. Move all authoritative menu, price, slot, discount, credit and fee rules to the database/backend. Never trust client values.
6. Store meals, payments, refunds, credits and add-ons in an auditable ledger; configure Row Level Security or equivalent authorization.
7. Replace illustrative provider/pricing fixtures with actual provider-configured records. The legal screens are drafts and need review before publication.

See the Antigravity prompt before making these replacements.
