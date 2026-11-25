# Page Specification: Kitchen Provider Overview (`ProviderOverview`)

> Inherits from `design-system/thali/MASTER.md`.

---

## Screen Architecture
- **Location:** `apps/mobile_provider/lib/main.dart` (`_ProviderOverviewState`)
- **Scaffolding:** `Scaffold(backgroundColor: const Color(0xFFFAF6EE))`
- **Header:** Provider business name, live counter status, and active slot timestamp.

## Critical Business Controls
1. **Kitchen Status Toggle Card:**
   - **Open State:** `#F0FDF4` background, `#86EFAC` border, `#15803D` text with check icon.
   - **Closed / Off State:** `#1E293B` dark slate container, `#475569` border, white bold text with lock icon.
   - **Persistence Guarantee:** Instant static lock in memory + `SharedPreferences` write + asynchronous API sync. Never flips unexpectedly or crashes with a toast.
2. **Counter Metrics Grid:**
   - 4-card grid: "Today's meals", "Active plans", "Subscribers", "Total scans".
   - Loading placeholder uses `IndeterminateBar` + `SkeletonShimmer`.
   - "Today's meals" metric icon wrapped in subtle `GradientRing`.
3. **Pending Approvals Card:**
   - `#FFF7ED` warm card with `#FED7AA` border, indicating awaiting cash/UPI transactions.
4. **Official Counter QR Card:**
   - Outer glow wrapped in `PulseRings`.
   - QR code matrix is completely static, black-on-white high contrast for 100% scan reliability.
