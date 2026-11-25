# Thali Ecosystem — Design System Master Specification (UI/UX Pro Max v2.0)

> **HIERARCHICAL RETRIEVAL RULE:**  
> When building or refactoring a specific page, first check `design-system/thali/pages/[page-name].md`.  
> If that file exists, its page-specific overrides take precedence.  
> If not, strictly adhere to this Master specification.

---

## 1. Product & Design Direction

- **Product:** Thali (Dine-in Mess Subscription & Daily Meal Check-in Platform)
- **Ecosystem:** 
  1. Thali Customer Mobile App (`apps/mobile_customer`)
  2. Thali Partner / Kitchen Mobile App (`apps/mobile_provider`)
  3. Thali Next.js Web Experience (`apps/web` at `https://www.thali.store`)
- **Category:** Food Service / Meal Subscription Box / Offline Counter Redemption
- **UI Style Pattern:** Vibrant & Block-Based + Soft UI Evolution (Modern Warm Food-Tech)
- **Tone:** Premium, dependable, appetizing, high-efficiency, clutter-free.

---

## 2. Global Color Tokens

All colors pass WCAG AA contrast (≥ 4.5:1 for body copy, ≥ 3:1 for large display headlines & badge text).

| Role | Semantic Name | Hex Code | Flutter Constant | CSS Variable | Usage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Primary Brand** | Thali Orange | `#FF6B1A` | `MessColors.orange` / `Color(0xFFFF6B1A)` | `--color-primary` | Main actions, highlights, primary buttons |
| **Primary Dark** | Deep Saffron / Amber | `#E94E12` | `MessColors.orangeDark` / `Color(0xFFE94E12)` | `--color-primary-dark` | Pressed states, active icons, badge text |
| **Golden Accent** | Thali Gold | `#FFB21A` | `Color(0xFFFFB21A)` | `--color-accent` | Secondary highlights, subscription rings |
| **Background** | Warm Cream | `#FAF6EE` | `MessColors.cream` / `Color(0xFFFAF6EE)` | `--color-background` | App surface, main scaffolding |
| **Card Surface** | Pure White | `#FFFFFF` | `Colors.white` | `--color-card` | Cards, elevated sheets, input fields |
| **Ink / Foreground** | Deep Navy Charcoal | `#111820` | `MessColors.ink` / `Color(0xFF111820)` | `--color-foreground` | Primary titles, bold copy, dark headers |
| **Muted Copy** | Slate Gray | `#687382` | `MessColors.muted` / `Color(0xFF687382)` | `--color-muted` | Subtitles, helper text, slot timestamps |
| **Border / Divider** | Warm Cream Border | `#E9E0D5` | `MessColors.border` / `Color(0xFFE9E0D5)` | `--color-border` | Subtle card dividers, input borders |
| **Success** | Emerald Green | `#16A34A` | `MessColors.green` / `Color(0xFF16A34A)` | `--color-success` | Active subscriptions, redeemed meals |
| **Success Light** | Mint Soft Tint | `#F0FDF4` | `Color(0xFFF0FDF4)` | `--color-success-light`| Success chips, open kitchen background |
| **Destructive** | Crimson Red | `#DC2626` | `MessColors.error` / `Color(0xFFDC2626)` | `--color-destructive`| Kitchen closed, delete actions, errors |
| **Destructive Light**| Rose Soft Tint | `#FEF2F2` | `Color(0xFFFEF2F2)` | `--color-destructive-light`| Danger containers, alert banners |

---

## 3. Typography & Hierarchy

- **Primary Sans:** Inter / Plus Jakarta Sans (Clean, high-legibility food-tech)
- **Display Accent:** Playfair Display SC (Subtle elegance on flagship headings)
- **Monospace:** JetBrains Mono (Cryptographic tokens, transaction IDs, OTPs)

```
Display Large:   28px / SemiBold (w700) / Tracking -0.02em / Navy #111820
Headline Medium: 20px / Bold (w700) / Tracking -0.01em / Navy #111820
Title Small:     16px / SemiBold (w600) / Navy #111820
Body Medium:     14px / Regular (w400) / LineHeight 1.5 / Ink #182435
Body Small:      12px / Medium (w500) / Slate Muted #687382
Micro Label:     11px / SemiBold (w600) / LetterSpacing 0.3px / Uppercase
```

---

## 4. Spacing & Elevation Scale

- **Scale:** 4px grid (`4px`, `8px`, `12px`, `16px`, `20px`, `24px`, `32px`, `48px`)
- **Card Radius:** `16px` (Modern soft rounded rectangle)
- **Button Radius:** `12px` (Pill / comfortable touch shape)
- **Input Radius:** `12px`
- **Shadow Soft:** `0 2px 8px rgba(17, 24, 32, 0.04)`
- **Shadow Float:** `0 8px 24px rgba(255, 107, 26, 0.12)`

---

## 5. UI/UX Pro Max Verification & Quality Checklist

### A. Iconography & Semantics
- [x] **No Raw Emojis as UI Icons:** All functional controls use Material Icons or Lucide SVG vectors. (Emoji is reserved solely for contextual feedback strings like 📸 or 🟢 in alerts).
- [x] **Accessible Icon Buttons:** Every `IconButton` must define a descriptive `tooltip` and minimum 44x44 dp touch bounding box.

### B. Contrast & Readability
- [x] **Light Mode Contrast:** Body text contrast ratio exceeds 4.5:1 against `#FAF6EE` background and `#FFFFFF` cards.
- [x] **Badge & Chip Colors:** Light pastel backgrounds (e.g. `#FFF7ED`, `#F0FDF4`) are paired with dark high-contrast foreground text (e.g. `#C2410C`, `#15803D`). Never use pale text on pale backgrounds.

### C. Reflow Resilience & Compact Layouts
- [x] **No Broken or Clipped Badges:** Chips and badge collections must wrap (`Wrap(spacing: 8, runSpacing: 8)`) or scroll smoothly (`SingleChildScrollView(scrollDirection: Axis.horizontal)`).
- [x] **Balanced Headings:** Headlines use responsive flex layouts (`Expanded`, `Flexible`) with sensible overflow handling (`TextOverflow.ellipsis` on single-line titles; multi-line wrapping on descriptions).

### D. Motion & Animation Standards
- [x] **Respects `prefers-reduced-motion`:** All 20 Thali animation widgets (`SpinnerArc`, `PulseRings`, `BouncingDots`, `LiquidFill`, etc.) query `MediaQuery.disableAnimationsOf(context)` and immediately halt motion loops.
- [x] **Performance Repaint Boundaries:** Heavy canvas-painted animations use `RepaintBoundary` to prevent full-screen layout repaints.
- [x] **Static Scannable QR Matrix:** Never animate QR code modules or matrix pixels. The cryptographic QR code is 100% static, surrounded only by an outer pulse frame.

### E. Touch & State Feedback
- [x] **Minimum Touch Target:** 44×44 dp on mobile touch targets.
- [x] **Instant State Feedback:** All interactive surfaces provide hover/press feedback with 150–250ms ease curves.
- [x] **Zero Fake Data:** Progress bars (`PercentBar`), remaining meal gauges (`LiquidFill`), and counter statistics use genuine backend numbers from Supabase / API.

---

## 6. Page-Level Retrieval Rules

1. **Customer App Home Screen:** [`pages/customer_home.md`](pages/customer_home.md)
   - Dynamic meal countdown, active subscription card with `GradientRing` & `LiquidFill`.
2. **Provider App Overview Screen:** [`pages/provider_overview.md`](pages/provider_overview.md)
   - Kitchen open/closed static toggle card, quick counter metrics, daily static QR viewer with `PulseRings`.
3. **Counter Attendance QR Redemption:**
   - Static QR cryptographic token valid for current meal slot; verification feedback uses `ChasingSquare` loader and celebratory `BouncingBall`.
