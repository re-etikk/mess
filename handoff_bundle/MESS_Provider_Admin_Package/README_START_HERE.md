# MESS Provider + Admin Handoff

This package contains a provider-side Flutter app starter, a responsive Next.js operations console, a draft Supabase schema, product/technical plans, an editable Word/PDF blueprint, and Antigravity prompts.

## Product scope

MESS is a meal-subscription and in-person meal-redemption platform. The provider's app helps a mess, restaurant, canteen, or home tiffin service register its business, set its verified location, configure meal slots, define plan types and prices, publish daily menus, define included portions and paid extras, create offers, display a daily provider QR, track redemptions, and review earnings.

**Delivery is out of scope for the current release.** The customer app scans the QR displayed by the provider. Never reverse this direction.

## What's included

- `provider_flutter/`: Flutter UI prototype for login, five-step business setup, overview dashboard, menu/portion management, subscription pricing, daily QR preview, offers, subscribers, attendance, earnings, support and settings.
- `admin_web/`: Next.js operations console prototype for provider review, customers, plans/menus, redemptions, payments, offers, support, roles, audit log and system health.
- `supabase/migrations/0001_provider_admin_core.sql`: proposed initial schema and minimum baseline policies. It is not a production-ready security review.
- `docs/`: PRD, technical architecture, app flow, admin roles, validation checklist and known edge cases.
- `MESS_Provider_Admin_Blueprint.docx` and `.pdf`: formatted blueprint for review or sharing.
- `prompts/`: master implementation, loop, and release-audit prompts for Antigravity.

## Run the provider Flutter prototype

```bash
cd provider_flutter
flutter pub get
flutter run
```

The Flutter SDK must be installed on your machine. The app uses demo workspace data. Authentication, map/location selection, business verification, plans, offers, live QR, menu persistence, settlements and support are not connected to a live backend.

## Run the admin web prototype

```bash
cd admin_web
npm install
npm run dev
```

Open the local URL printed by Next.js. It is a local UI prototype; it does not contain production login, server-side authorization, or live data. All sample records are visibly marked as demo.

## Recommended Antigravity order

1. Open the actual MESS repository, not just this package.
2. Paste `prompts/ANTIGRAVITY_MASTER_PROMPT.md`.
3. Ask the agent to inspect the repository and plan a safe merge. Do not overwrite existing working code, environment files or migrations.
4. Integrate the provider Flutter flows and admin web app with the shared backend.
5. Use `prompts/LOOP_CONTINUE_PROMPT.md` after each phase.
6. Use `prompts/RELEASE_AUDIT_PROMPT.md` before release.

## Critical safety note

The daily QR page currently renders a visible, non-redeemable `MESS_DEMO_PROVIDER_QR` preview. A production QR must be issued by a trusted backend, bind to provider + local service date, be signed or otherwise unforgeable, and be verified at redemption time. Never put Supabase service-role keys, payment secrets, or privileged admin credentials in Flutter/browser code.

The SQL includes RLS but only a minimal baseline set of policies. Review and add role-specific RLS policies, server-side handlers, database transaction tests, and admin authorization before exposing data. Do not deploy this migration into a live database without a migration review and backup.

## Design direction

- Brand: MESS
- Palette: cream `#FAF6EE`, navy `#142433`, orange `#F59A16`, muted green for success
- No purple gradients, excessive pill shapes, emoji icons, fake reviews, fake customer counters, invented analytics, AI-generated food imagery, or “made with AI” badges
- Use provider-uploaded food photos only; the prototype uses icon placeholders to avoid fabricated photography
- Mobile-first, no horizontal page overflow, accessible forms, visible loading/error/success states, restrained tap/page animation

## Verification status

- The blueprint DOCX was rendered to eight pages and visually inspected; the matching PDF is included.
- Admin Next.js source files passed a TypeScript transpile syntax check. This is not a full TypeScript typecheck or Next.js build.
- The Flutter SDK was unavailable in the authoring environment, so `flutter pub get`, `flutter analyze`, `flutter test`, and an Android build were not run.
- Dependency installation for the admin web prototype did not complete in this environment; run `npm install`, `npm run typecheck`, `npm run lint`, and `npm run build` on your machine.
- The Supabase SQL migration is a reviewable draft. It was not applied to a staging database and has not been SQL-parser or policy-test verified.
- All live authentication, OAuth, location/map, data fetching, payment, settlements and redemption endpoints must be integrated and tested before production use.
