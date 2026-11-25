# Page Specification: Customer Home Screen (`HomeScreen`)

> Inherits from `design-system/thali/MASTER.md`. The rules below represent page-specific implementation details.

---

## Screen Architecture
- **Location:** `apps/mobile_customer/lib/features/home/home_screen.dart`
- **Scaffolding:** `Scaffold(backgroundColor: MessColors.cream)`
- **Header:** Sticky greeting banner with user name, active meal slot indicator (Breakfast / Lunch / Dinner), and quick notification bell.

## Component Layout & Animations
1. **Active Subscription Card:**
   - **Background:** White card surface `#FFFFFF` with `16px` border radius and `1.5px` border `#E9E0D5`.
   - **Active State Indicator:** `GradientRing` (22px diameter, colors: `#FF6B1A` to `#FFB21A`) around the green status dot.
   - **Meal Meter:** `LiquidFill` gauge rendered with exact backend data (`remainingMeals / totalMeals`).
   - **Progress Tracking:** `PercentBar` displaying true consumption ratio.
2. **Nearby Mess Explorer:**
   - **Loading State:** `SkeletonShimmer` cards with warm bone `#EDE8DF` highlight `#FAF6EE`.
   - **Empty State:** `EmptyStateCard` with clear call to action.
   - **Mess Cards:** High-contrast tags (e.g. "Pure Veg" `#16A34A` on `#F0FDF4`, "Rating 4.8" `#C2410C` on `#FFF7ED`). No clipped chips.

## Verification
- [x] Tested with 0 subscriptions, 1 active subscription, and expired subscriptions.
- [x] Text reflows cleanly on 320dp small phone screens up to 600dp foldables.
- [x] Animation pauses when user enables system reduced motion.
