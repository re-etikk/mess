import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/models/mess_models.dart';
import '../../core/repositories/mess_repository.dart';
import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../mess/mess_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../scan/scan_screen.dart';
import '../search/search_screen.dart';
import '../setup/profile_location_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MessProvider> _providers = [];
  bool _loading = true;
  String? _error;

  String? _selectedSlot; // 'breakfast' | 'lunch' | 'snacks' | 'dinner'
  double? _minRating;
  bool _openNowOnly = false;
  bool _deliveryOnly = false;
  String _sortBy = ''; // '' | 'rating' | 'price' | 'distance'
  final Set<String> _favorites = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProviders());
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appState = AppStateScope.of(context, listen: false);
      appState.refreshRemoteConfig();
      var list = await appState.getProviders(
        slot: _selectedSlot,
        minRating: _minRating,
        openNow: _openNowOnly,
        deliveryOnly: _deliveryOnly,
        sort: _sortBy.isEmpty ? null : _sortBy,
      );
      if (_selectedSlot != null && _selectedSlot!.isNotEmpty) {
        final sKey = _selectedSlot!.toLowerCase();
        list = list.where((p) => p.mealSlots.any((m) => m.id.toLowerCase() == sKey && m.enabled)).toList();
      }
      if (_openNowOnly) {
        list = list.where((p) => p.isOpen).toList();
      }
      if (!mounted) return;
      setState(() => _providers = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyCustomerError(e, action: 'load kitchens'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openNotificationsSheet() {
    final appState = AppStateScope.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Notifications', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                  if (appState.notifications.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        appState.markAllNotificationsRead();
                        Navigator.pop(context);
                      },
                      child: const Text('Mark all read', style: TextStyle(color: ThaliColors.primary, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (appState.notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No notifications yet.', style: TextStyle(fontSize: 13.5, color: ThaliColors.muted)),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: appState.notifications.length.clamp(0, 15),
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final n = appState.notifications[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: n.isRead ? ThaliColors.subtle : ThaliColors.primarySoft,
                          child: Icon(Icons.notifications_none_rounded, size: 18, color: n.isRead ? ThaliColors.muted : ThaliColors.primary),
                        ),
                        title: Text(n.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                        subtitle: Text(n.message, style: const TextStyle(fontSize: 12, color: ThaliColors.body)),
                        onTap: () => appState.markNotificationRead(n.id),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            const Text('Sort messes by', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
            const SizedBox(height: 8),
            for (final opt in [
              ('', 'Recommended'),
              ('rating', 'Highest Rated'),
              ('price', 'Lowest Meal Price'),
              ('distance', 'Nearest First'),
            ])
              RadioListTile<String>(
                value: opt.$1,
                groupValue: _sortBy,
                activeColor: ThaliColors.primary,
                title: Text(opt.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                onChanged: (v) {
                  Navigator.pop(ctx);
                  setState(() => _sortBy = v ?? '');
                  _loadProviders();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final locTitle = appState.location.isNotEmpty ? appState.location : 'Select location';
    final locSub = appState.selectedCity.isNotEmpty ? '${appState.location}, ${appState.selectedCity}' : 'Tap to set delivery area';
    final initials = appState.customerName.trim().isNotEmpty ? appState.customerName.trim()[0].toUpperCase() : 'U';

    return RefreshIndicator(
      color: ThaliColors.primary,
      onRefresh: _loadProviders,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 18),
              decoration: const BoxDecoration(
                color: ThaliColors.primary,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final changed = await Navigator.push(
                              context,
                              messRoute(const ProfileLocationSetupScreen(locationOnly: true)),
                            );
                            if (changed == true) _loadProviders();
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 17, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      locTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 21),
                                child: Text(
                                  locSub,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.9)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => Navigator.push(context, messRoute(const ScanScreen())),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const Icon(Icons.qr_code_scanner_rounded, size: 19, color: ThaliColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Stack(
                        children: [
                          InkWell(
                            onTap: _openNotificationsSheet,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: const Icon(Icons.notifications_none_rounded, size: 20, color: ThaliColors.ink),
                            ),
                          ),
                          if (appState.unreadNotificationsCount > 0)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(color: ThaliColors.ink, shape: BoxShape.circle),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => Navigator.push(context, messRoute(const ProfileScreen())),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: ThaliColors.ink,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(initials, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => Navigator.push(context, messRoute(const SearchScreen())),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.search_rounded, size: 19, color: ThaliColors.muted),
                          SizedBox(width: 9),
                          Text('Search messes or areas', style: TextStyle(fontSize: 13.5, color: ThaliColors.muted, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.heroHeadline,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appState.heroSubheadline,
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.92)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
                          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/ui/cover_default_kitchen.jpg',
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 4 Quick Slot Category Cards (Breakfast · Lunch · Snacks · Dinner)
                Row(
                  children: [
                    _SlotCategoryTile(
                      label: 'Breakfast',
                      imagePath: 'assets/images/ui/slot_breakfast.jpg',
                      svgPath: 'assets/images/ui/icon_breakfast.svg',
                      bg: ThaliColors.breakfastTile,
                      selected: _selectedSlot == 'breakfast',
                      onTap: () {
                        setState(() => _selectedSlot = _selectedSlot == 'breakfast' ? null : 'breakfast');
                        _loadProviders();
                      },
                    ),
                    const SizedBox(width: 7),
                    _SlotCategoryTile(
                      label: 'Lunch',
                      imagePath: 'assets/images/ui/slot_lunch.jpg',
                      svgPath: 'assets/images/ui/icon_lunch.svg',
                      bg: ThaliColors.lunchTile,
                      selected: _selectedSlot == 'lunch',
                      onTap: () {
                        setState(() => _selectedSlot = _selectedSlot == 'lunch' ? null : 'lunch');
                        _loadProviders();
                      },
                    ),
                    const SizedBox(width: 7),
                    _SlotCategoryTile(
                      label: 'Snacks',
                      imagePath: 'assets/images/ui/slot_snacks.jpg',
                      svgPath: 'assets/images/ui/icon_snacks.svg',
                      bg: ThaliColors.snacksTile,
                      selected: _selectedSlot == 'snacks',
                      onTap: () {
                        setState(() => _selectedSlot = _selectedSlot == 'snacks' ? null : 'snacks');
                        _loadProviders();
                      },
                    ),
                    const SizedBox(width: 7),
                    _SlotCategoryTile(
                      label: 'Dinner',
                      imagePath: 'assets/images/ui/slot_dinner.jpg',
                      svgPath: 'assets/images/ui/icon_dinner.svg',
                      bg: ThaliColors.dinnerTile,
                      selected: _selectedSlot == 'dinner',
                      onTap: () {
                        setState(() => _selectedSlot = _selectedSlot == 'dinner' ? null : 'dinner');
                        _loadProviders();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Outlined Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChipButton(
                        label: _sortBy.isEmpty ? 'Sort by' : 'Sort: $_sortBy',
                        icon: Icons.tune_rounded,
                        trailingIcon: Icons.keyboard_arrow_down_rounded,
                        selected: _sortBy.isNotEmpty,
                        onTap: _openSortSheet,
                      ),
                      const SizedBox(width: 8),
                      _FilterChipButton(
                        label: '3+',
                        trailingStar: true,
                        selected: _minRating == 3,
                        onTap: () {
                          setState(() => _minRating = _minRating == 3 ? null : 3);
                          _loadProviders();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChipButton(
                        label: '4+',
                        trailingStar: true,
                        selected: _minRating == 4,
                        onTap: () {
                          setState(() => _minRating = _minRating == 4 ? null : 4);
                          _loadProviders();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChipButton(
                        label: 'Open now',
                        selected: _openNowOnly,
                        onTap: () {
                          setState(() => _openNowOnly = !_openNowOnly);
                          _loadProviders();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChipButton(
                        label: 'Self Delivery',
                        icon: Icons.delivery_dining_outlined,
                        selected: _deliveryOnly,
                        onTap: () {
                          setState(() => _deliveryOnly = !_deliveryOnly);
                          _loadProviders();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (appState.maintenanceMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB91C1C)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              appState.maintenanceMessage.isNotEmpty
                                  ? appState.maintenanceMessage
                                  : 'Scheduled maintenance is underway. New checkouts may be paused briefly.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (appState.announcements.isNotEmpty) ...[
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: appState.announcements.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, idx) {
                        final b = appState.announcements[idx];
                        final promo = b['promo_code']?.toString() ?? '';
                        return Container(
                          width: 268,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: ThaliColors.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ThaliColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      b['title']?.toString() ?? 'Offer',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                                    ),
                                  ),
                                  if (promo.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: ThaliColors.primary, borderRadius: BorderRadius.circular(6)),
                                      child: Text(promo, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Flexible(
                                child: Text(
                                  b['body']?.toString() ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: ThaliColors.body),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_loading)
                  const ThaliListSkeleton(itemCount: 3, cardHeight: 168)
                else if (_error != null)
                  CardSurface(
                    child: Column(
                      children: [
                        Text(_error!, style: const TextStyle(fontSize: 13, color: ThaliColors.red)),
                        const SizedBox(height: 10),
                        MessActionButton(label: 'Retry', onPressed: _loadProviders, height: 42),
                      ],
                    ),
                  )
                else if (_providers.isEmpty)
                  CardSurface(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    child: Column(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 42, color: ThaliColors.muted),
                        const SizedBox(height: 10),
                        const Text('No messes found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                        const SizedBox(height: 4),
                        const Text(
                          'Try clearing filters or switching to another locality.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: ThaliColors.muted),
                        ),
                        const SizedBox(height: 14),
                        MessActionButton(
                          label: 'Reset Filters',
                          secondary: true,
                          height: 42,
                          onPressed: () {
                            setState(() {
                              _selectedSlot = null;
                              _minRating = null;
                              _openNowOnly = false;
                              _deliveryOnly = false;
                              _sortBy = '';
                            });
                            _loadProviders();
                          },
                        ),
                      ],
                    ),
                  )
                else ...[
                  SectionHeader(
                    title: appState.location.isNotEmpty ? 'Nearby in ${appState.location}' : 'Nearby Messes',
                    actionLabel: 'See all',
                    onAction: () => Navigator.push(context, messRoute(const SearchScreen())),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 176,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _providers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final p = _providers[i];
                        final isClosed = !p.isOpen;
                        return SizedBox(
                          width: 120,
                          child: InkWell(
                            onTap: () => Navigator.push(context, messRoute(MessDetailScreen(provider: p))),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: isClosed ? const EdgeInsets.all(6) : EdgeInsets.zero,
                              decoration: isClosed
                                  ? BoxDecoration(
                                      color: const Color(0xFF141416),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF27272A)),
                                    )
                                  : null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MessCoverVisual(
                                    imageUrl: p.coverPath,
                                    height: isClosed ? 96 : 106,
                                    radius: 10,
                                    closed: isClosed,
                                    caption: p.startingMealPrice != null ? 'Meals at ₹${p.startingMealPrice}' : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isClosed ? Colors.white : ThaliColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  isClosed
                                      ? const Text(
                                          'Closed today',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFA1A1AA)),
                                        )
                                      : RatingBadge(rating: p.rating, compact: true),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  SectionHeader(
                    title: _openNowOnly ? 'Open now' : 'Explore Messes',
                    actionLabel: 'See all',
                    onAction: () => Navigator.push(context, messRoute(const SearchScreen())),
                  ),
                  const SizedBox(height: 10),
                  for (final p in _providers)
                    Builder(
                      builder: (_) {
                        final isClosed = !p.isOpen;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CardSurface(
                            padding: const EdgeInsets.all(10),
                            color: isClosed ? const Color(0xFF141416) : ThaliColors.card,
                            borderColor: isClosed ? const Color(0xFF27272A) : null,
                            onTap: () => Navigator.push(context, messRoute(MessDetailScreen(provider: p))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    MessCoverVisual(
                                      imageUrl: p.coverPath,
                                      height: 142,
                                      radius: 10,
                                      closed: isClosed,
                                    ),
                                    if (p.subscriberCount > 0)
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.94),
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            p.subscriberCount >= 99 ? '99+ subscribers' : '${p.subscriberCount} subscribers',
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: InkWell(
                                        onTap: () => setState(() {
                                          if (_favorites.contains(p.id)) {
                                            _favorites.remove(p.id);
                                          } else {
                                            _favorites.add(p.id);
                                          }
                                        }),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.94),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            _favorites.contains(p.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            size: 17,
                                            color: _favorites.contains(p.id) ? ThaliColors.primary : ThaliColors.ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  p.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: isClosed ? Colors.white : ThaliColors.ink,
                                                  ),
                                                ),
                                              ),
                                              if (p.isFeatured && !isClosed) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: ThaliColors.amberSoft,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'Featured',
                                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: ThaliColors.amberDark),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${p.isOpen ? 'Open' : 'Closed · Off Today'} · ${p.area.isNotEmpty ? p.area : p.city}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isClosed ? const Color(0xFFE4E4E7) : ThaliColors.greenDark,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            p.mealSlots.isEmpty
                                                ? 'Daily Subscriptions'
                                                : p.mealSlots.map((s) => s.name).join(' · '),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isClosed ? const Color(0xFFA1A1AA) : ThaliColors.muted,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: isClosed
                                                      ? const Color(0xFF27272A)
                                                      : (p.supportsDelivery ? ThaliColors.primarySoft : ThaliColors.subtle),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isClosed
                                                          ? Icons.lock_outline_rounded
                                                          : (p.supportsDelivery ? Icons.delivery_dining_rounded : Icons.storefront_outlined),
                                                      size: 12,
                                                      color: isClosed
                                                          ? const Color(0xFFD4D4D8)
                                                          : (p.supportsDelivery ? ThaliColors.primary : ThaliColors.muted),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isClosed
                                                          ? 'Off Today'
                                                          : (p.supportsDelivery ? 'Self Delivery' : 'Pickup / Dine-in'),
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: isClosed
                                                            ? const Color(0xFFE4E4E7)
                                                            : (p.supportsDelivery ? ThaliColors.primary : ThaliColors.body),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (p.startingMealPrice != null)
                                                Text(
                                                  'From ₹${p.startingMealPrice}/meal',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: isClosed ? Colors.white : ThaliColors.ink,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    RatingBadge(rating: p.rating),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCategoryTile extends StatelessWidget {
  const _SlotCategoryTile({
    required this.label,
    required this.imagePath,
    required this.svgPath,
    required this.bg,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String imagePath;
  final String svgPath;
  final Color bg;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? ThaliColors.primarySoft : bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? ThaliColors.primary : ThaliColors.stroke,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: ClipOval(
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    cacheWidth: 180,
                    errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(6),
                      child: SvgPicture.asset(svgPath, width: 32, height: 32),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: selected ? ThaliColors.primaryDark : ThaliColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
    this.trailingIcon,
    this.trailingStar = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool trailingStar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? ThaliColors.primarySoft : ThaliColors.card,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? ThaliColors.primary : ThaliColors.stroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? ThaliColors.primary : ThaliColors.ink),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? ThaliColors.primary : ThaliColors.ink),
            ),
            if (trailingStar) ...[
              const SizedBox(width: 3),
              const Icon(Icons.star_rounded, size: 13.5, color: ThaliColors.amber),
            ],
            if (trailingIcon != null) ...[
              const SizedBox(width: 3),
              Icon(trailingIcon, size: 15, color: selected ? ThaliColors.primary : ThaliColors.ink),
            ],
          ],
        ),
      ),
    );
  }
}
