import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/mess_models.dart';
import '../../core/repositories/mess_repository.dart';
import '../../core/services/customer_auth_service.dart';
import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../chat/customer_chat_screen.dart';
import '../scan/scan_screen.dart';

class MyMealsScreen extends StatefulWidget {
  const MyMealsScreen({super.key});

  @override
  State<MyMealsScreen> createState() => _MyMealsScreenState();
}

class _MyMealsScreenState extends State<MyMealsScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  String? _error;

  bool _hasActiveSubscription = false;
  bool _isBreakDay = false;
  int _skipAllowance = 2;
  int _skipsUsed = 0;
  int _remainingSkips = 2;
  String _providerName = '';
  List<CustomerWeekDay> _weekDays = const [];
  List<DailyMealItem> _meals = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeals());
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _monthYearLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Future<void> _loadMeals() async {
    final appState = AppStateScope.of(context, listen: false);
    if (appState.customerId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasActiveSubscription = false;
          _meals = const [];
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await appState.repository.fetchCustomerMeals(
        customerId: appState.customerId,
        dateStr: _isoDate(_selectedDate),
      );
      if (!mounted) return;
      final weekRaw = (res['week_days'] as List?) ?? const [];
      final mealsRaw = (res['meals'] as List?) ?? const [];
      setState(() {
        _hasActiveSubscription = res['has_active_subscription'] == true;
        _isBreakDay = res['is_break_day'] == true;
        _skipAllowance = (res['skip_allowance'] as num?)?.toInt() ?? 2;
        _skipsUsed = (res['skips_used'] as num?)?.toInt() ?? 0;
        _remainingSkips = (res['remaining_skips'] as num?)?.toInt() ??
            (_skipAllowance - _skipsUsed).clamp(0, 99);
        _providerName = res['provider_name']?.toString() ?? '';
        _weekDays = weekRaw
            .map((e) => CustomerWeekDay.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _meals = mealsRaw
            .map((e) => DailyMealItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyCustomerError(e, action: 'load daily meals'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: ThaliColors.primary,
            onPrimary: Colors.white,
            onSurface: ThaliColors.ink,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      await _loadMeals();
    }
  }

  List<CustomerWeekDay> _effectiveWeekDays() {
    if (_weekDays.isNotEmpty) return _weekDays;
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(7, (i) {
      final d = startOfWeek.add(Duration(days: i));
      final iso = _isoDate(d);
      return CustomerWeekDay(
        date: iso,
        dayLabel: labels[d.weekday - 1],
        dayNumber: d.day,
        isSelected: iso == _isoDate(_selectedDate),
        indicator: _hasActiveSubscription ? 'scheduled' : 'break_day',
      );
    });
  }

  DailyMealItem? _nextUpcomingMeal() {
    for (final m in _meals) {
      final st = m.status.toLowerCase();
      if (st != 'delivered' && st != 'redeemed' && st != 'skipped' && st != 'cancelled_by_kitchen') {
        return m;
      }
    }
    return _meals.isNotEmpty ? _meals.first : null;
  }

  int _upcomingCount() {
    return _meals.where((m) {
      final st = m.status.toLowerCase();
      return st != 'delivered' && st != 'redeemed' && st != 'skipped' && st != 'cancelled_by_kitchen';
    }).length;
  }

  Widget _slotSvg(String slot, {double size = 34}) {
    final s = slot.toLowerCase();
    final asset = s.contains('breakfast')
        ? 'assets/images/ui/icon_breakfast.svg'
        : s.contains('dinner')
            ? 'assets/images/ui/icon_dinner.svg'
            : 'assets/images/ui/icon_lunch.svg';
    return Container(
      width: size + 10,
      height: size + 10,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: s.contains('breakfast')
            ? ThaliColors.breakfastTile
            : s.contains('dinner')
                ? ThaliColors.dinnerTile
                : ThaliColors.lunchTile,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SvgPicture.asset(
        asset,
        width: size,
        height: size,
        placeholderBuilder: (_) => FoodGlyph(name: slot, size: size),
      ),
    );
  }

  Widget _dayIndicatorDot(CustomerWeekDay d, bool selected) {
    final ind = d.indicator.toLowerCase();
    if (ind == 'skipped') {
      return Icon(
        Icons.close_rounded,
        size: 11,
        color: selected ? Colors.white : ThaliColors.red,
      );
    }
    if (ind == 'completed' || ind == 'delivered' || ind == 'redeemed') {
      return Container(
        width: 5.5,
        height: 5.5,
        decoration: BoxDecoration(
          color: selected ? Colors.white : ThaliColors.green,
          shape: BoxShape.circle,
        ),
      );
    }
    if (ind == 'break_day') {
      return Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.7) : ThaliColors.border,
          shape: BoxShape.circle,
        ),
      );
    }
    return Container(
      width: 5.5,
      height: 5.5,
      decoration: BoxDecoration(
        color: selected ? Colors.white : ThaliColors.amber,
        shape: BoxShape.circle,
      ),
    );
  }

  Future<void> _openMealManage(DailyMealItem meal) async {
    final updated = await Navigator.push<bool>(
      context,
      messRoute(
        MealManageScreen(
          meal: meal,
          allMealsForDay: _meals,
          skipAllowance: _skipAllowance,
          remainingSkips: _remainingSkips,
        ),
      ),
    );
    if (updated == true || mounted) {
      await _loadMeals();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final weekDays = _effectiveWeekDays();
    final upcomingCount = _upcomingCount();
    final nextMeal = _nextUpcomingMeal();

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Behance Clean Top App Bar + 7-Day Strip
            Container(
              decoration: const BoxDecoration(
                color: ThaliColors.card,
                border: Border(bottom: BorderSide(color: ThaliColors.stroke)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        if (Navigator.canPop(context))
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.chevron_left_rounded, size: 24, color: ThaliColors.ink),
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(32, 32),
                              ),
                            ),
                          ),
                        const Expanded(
                          child: Text(
                            'Your Meals',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: ThaliColors.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        PressScale(
                          onTap: () async {
                            await Navigator.push(context, messRoute(const ScanScreen()));
                            if (mounted) _loadMeals();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: ThaliColors.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ThaliColors.primary.withValues(alpha: 0.35)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.qr_code_scanner_rounded, size: 15, color: ThaliColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Scan QR',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: ThaliColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        PressScale(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: ThaliColors.subtle,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: ThaliColors.stroke),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _monthYearLabel(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: ThaliColors.ink,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: ThaliColors.ink),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 14),
                    child: Row(
                      children: weekDays.map((wd) {
                        final isSelected = wd.isSelected || wd.date == _isoDate(_selectedDate);
                        return Expanded(
                          child: PressScale(
                            onTap: () {
                              final parsed = DateTime.tryParse(wd.date);
                              if (parsed != null) {
                                setState(() => _selectedDate = parsed);
                                _loadMeals();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? ThaliColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    wd.dayLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white.withValues(alpha: 0.9) : ThaliColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${wd.dayNumber}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? Colors.white : ThaliColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  _dayIndicatorDot(wd, isSelected),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: RefreshIndicator(
                color: ThaliColors.primary,
                onRefresh: _loadMeals,
                child: _loading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                        children: const [ThaliListSkeleton(itemCount: 3, cardHeight: 126)],
                      )
                    : _error != null
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 28, 16, 120),
                            children: [
                              CardSurface(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    const Icon(Icons.cloud_off_rounded, size: 36, color: ThaliColors.muted),
                                    const SizedBox(height: 10),
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: ThaliColors.body, fontSize: 13.5),
                                    ),
                                    const SizedBox(height: 14),
                                    MessActionButton(label: 'Retry', onPressed: _loadMeals, height: 44),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : !_hasActiveSubscription
                            ? _buildNoSubscriptionState(appState)
                            : _isBreakDay || _meals.isEmpty
                                ? _buildBreakDayState(appState)
                                : ListView(
                                    physics: const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 118),
                                    children: [
                                      _buildSummaryCard(upcomingCount, nextMeal),
                                      const SizedBox(height: 12),
                                      _buildQuickScanCard(),
                                      const SizedBox(height: 16),
                                      _buildMessScheduleCard(appState),
                                    ],
                                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSubscriptionState(dynamic appState) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(24, 38, 24, 118),
      children: [
        CardSurface(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          child: Column(
            children: [
              SvgPicture.asset(
                'assets/images/ui/illus_empty_meals.svg',
                height: 150,
                placeholderBuilder: (_) => const Icon(
                  Icons.room_service_outlined,
                  size: 64,
                  color: ThaliColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No meals scheduled today',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink),
              ),
              const SizedBox(height: 6),
              const Text(
                'Subscribe to a verified mess kitchen near you to track daily Breakfast, Lunch and Dinner.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: ThaliColors.muted, height: 1.45),
              ),
              const SizedBox(height: 20),
              MessActionButton(
                label: 'Explore Messes',
                onPressed: () => appState.selectTab(0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreakDayState(dynamic appState) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 118),
      children: [
        CardSurface(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
          child: Column(
            children: [
              SvgPicture.asset(
                'assets/images/ui/illus_paused_cal.svg',
                height: 140,
                placeholderBuilder: (_) => const Icon(
                  Icons.event_busy_outlined,
                  size: 58,
                  color: ThaliColors.amber,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No meals on ${formatDate(_selectedDate)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
              ),
              const SizedBox(height: 6),
              const Text(
                'This date is marked as a pause window or non-delivery weekday on your subscription.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: ThaliColors.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              MessActionButton(
                label: 'Manage Subscription',
                secondary: true,
                onPressed: () => appState.selectTab(2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(int upcomingCount, DailyMealItem? nextMeal) {
    final fulfillment = nextMeal == null
        ? '--'
        : (nextMeal.fulfillmentMode.toLowerCase().contains('pickup') ||
                nextMeal.fulfillmentMode.toLowerCase().contains('counter'))
            ? 'Mess Counter'
            : 'Delivery';
    final etaText = nextMeal == null
        ? '--'
        : nextMeal.etaMinutes != null
            ? '${nextMeal.etaMinutes} mins'
            : nextMeal.timeWindow;

    return CardSurface(
      color: ThaliColors.card,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Showing for ${formatDate(_selectedDate)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThaliColors.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$upcomingCount upcoming meal${upcomingCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: ThaliColors.ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              _slotSvg(nextMeal?.slot ?? 'lunch', size: 36),
            ],
          ),
          if (nextMeal != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThaliColors.scaffold,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThaliColors.stroke),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Next meal', style: TextStyle(fontSize: 11, color: ThaliColors.muted)),
                        const SizedBox(height: 3),
                        Text(
                          etaText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 26, color: ThaliColors.stroke),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fulfillment', style: TextStyle(fontSize: 11, color: ThaliColors.muted)),
                        const SizedBox(height: 3),
                        Text(
                          fulfillment,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  MealStatusBadge(status: nextMeal.status),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickScanCard() {
    return CardSurface(
      onTap: () async {
        await Navigator.push(context, messRoute(const ScanScreen()));
        if (mounted) await _loadMeals();
      },
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ThaliColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: ThaliColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan Counter QR',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                ),
                SizedBox(height: 2),
                Text(
                  'At the kitchen? Check in instantly for dine-in or pickup.',
                  style: TextStyle(fontSize: 12, color: ThaliColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: ThaliColors.primary,
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'Scan QR',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessScheduleCard(dynamic appState) {
    final titleName = _providerName.isNotEmpty
        ? _providerName
        : (_meals.isNotEmpty ? _meals.first.providerName : 'Active Mess');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleName,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                    ),
                    Text(
                      '$_remainingSkips of $_skipAllowance skips left this week',
                      style: const TextStyle(fontSize: 12, color: ThaliColors.muted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  if (_meals.isNotEmpty) {
                    _openMealManage(_meals.first);
                  } else {
                    appState.selectTab(2);
                  }
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Manage', style: TextStyle(fontWeight: FontWeight.w700, color: ThaliColors.primary)),
                    Icon(Icons.chevron_right_rounded, size: 18, color: ThaliColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
        ..._meals.map((meal) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CardSurface(
                onTap: () => _openMealManage(meal),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _slotSvg(meal.slot),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  meal.slotLabel,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: ThaliColors.ink,
                                  ),
                                ),
                              ),
                              MealStatusBadge(status: meal.status),
                            ],
                          ),
                          const SizedBox(height: 5),
                          if (meal.menuSummary.isNotEmpty)
                            Text(
                              meal.menuSummary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: ThaliColors.body, height: 1.35),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 13.5, color: ThaliColors.muted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  meal.timeWindow.isNotEmpty ? meal.timeWindow : 'Standard meal hours',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThaliColors.muted),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: meal.fulfillmentMode == 'delivery' ? ThaliColors.primarySoft : ThaliColors.subtle,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  meal.fulfillmentMode == 'delivery' ? 'Self Delivery' : 'Counter Pickup',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: meal.fulfillmentMode == 'delivery' ? ThaliColors.primary : ThaliColors.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded, size: 18, color: ThaliColors.muted),
                            ],
                          ),
                          if (meal.riderName != null && meal.riderName!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: ThaliColors.greenSoft,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: ThaliColors.green.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.delivery_dining_rounded, size: 15, color: ThaliColors.greenDark),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      meal.riderLat != null && meal.riderLng != null
                                          ? 'Rider: ${meal.riderName} (Live GPS)'
                                          : 'Rider: ${meal.riderName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ThaliColors.greenDark),
                                    ),
                                  ),
                                  if (meal.riderPhone != null && meal.riderPhone!.isNotEmpty)
                                    InkWell(
                                      onTap: () => launchUrl(Uri.parse('tel:${meal.riderPhone}')),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: Icon(Icons.call_rounded, size: 15, color: ThaliColors.greenDark),
                                      ),
                                    ),
                                  if (meal.riderLat != null && meal.riderLng != null)
                                    InkWell(
                                      onTap: () => launchUrl(
                                        Uri.parse('https://www.google.com/maps/search/?api=1&query=${meal.riderLat},${meal.riderLng}'),
                                        mode: LaunchMode.externalApplication,
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Icon(Icons.location_on_rounded, size: 15, color: ThaliColors.primary),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

class MealManageScreen extends StatefulWidget {
  const MealManageScreen({
    super.key,
    required this.meal,
    required this.allMealsForDay,
    required this.skipAllowance,
    required this.remainingSkips,
  });

  final DailyMealItem meal;
  final List<DailyMealItem> allMealsForDay;
  final int skipAllowance;
  final int remainingSkips;

  @override
  State<MealManageScreen> createState() => _MealManageScreenState();
}

class _MealManageScreenState extends State<MealManageScreen> {
  late DailyMealItem _meal;
  late int _remainingSkips;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _meal = widget.meal;
    _remainingSkips = widget.remainingSkips;
  }

  bool get _canModify {
    final st = _meal.status.toLowerCase();
    return st == 'scheduled' || st == 'preparing';
  }

  List<String> _rescheduleWindows(String slot) {
    final s = slot.toLowerCase();
    if (s.contains('breakfast')) {
      return ['07:30 AM - 08:30 AM', '08:30 AM - 09:30 AM', '09:30 AM - 10:30 AM'];
    }
    if (s.contains('dinner')) {
      return ['07:30 PM - 08:30 PM', '08:30 PM - 09:30 PM', '09:30 PM - 10:30 PM'];
    }
    return ['12:00 PM - 01:00 PM', '01:00 PM - 02:00 PM', '02:00 PM - 03:00 PM'];
  }

  Future<void> _rescheduleSheet() async {
    final options = _rescheduleWindows(_meal.slot);
    String chosen = options.contains(_meal.timeWindow) ? _meal.timeWindow : options.first;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: ThaliColors.stroke, borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reschedule ${_meal.slotLabel}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose a preferred delivery or pickup window for today.',
                  style: TextStyle(fontSize: 13, color: ThaliColors.muted),
                ),
                const SizedBox(height: 16),
                ...options.map((slotTime) {
                  final active = chosen == slotTime;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CardSurface(
                      onTap: () => setSheetState(() => chosen = slotTime),
                      color: active ? ThaliColors.primarySoft : ThaliColors.card,
                      borderColor: active ? ThaliColors.primary : ThaliColors.stroke,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      child: Row(
                        children: [
                          Icon(
                            active ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 20,
                            color: active ? ThaliColors.primary : ThaliColors.muted,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            slotTime,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: active ? ThaliColors.primaryDark : ThaliColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 6),
                MessActionButton(
                  label: 'Update Time Slot',
                  onPressed: () => Navigator.pop(ctx, chosen),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final appState = AppStateScope.of(context, listen: false);
      await appState.repository.postMealAction(
        action: 'reschedule',
        subscriptionId: _meal.subscriptionId,
        customerId: appState.customerId,
        providerId: _meal.providerId,
        serviceDate: _meal.serviceDate,
        slot: _meal.slot,
        customTimeSlot: selected,
      );
      if (!mounted) return;
      setState(() {
        _changed = true;
        _meal = DailyMealItem(
          id: _meal.id,
          subscriptionId: _meal.subscriptionId,
          providerId: _meal.providerId,
          providerName: _meal.providerName,
          providerPhone: _meal.providerPhone,
          providerLocality: _meal.providerLocality,
          serviceDate: _meal.serviceDate,
          slot: _meal.slot,
          slotLabel: _meal.slotLabel,
          menuSummary: _meal.menuSummary,
          timeWindow: selected,
          status: _meal.status,
          fulfillmentMode: _meal.fulfillmentMode,
          instructions: _meal.instructions,
          etaMinutes: _meal.etaMinutes,
          cutoffTime: _meal.cutoffTime,
          providerLat: _meal.providerLat,
          providerLng: _meal.providerLng,
          riderName: _meal.riderName,
          riderPhone: _meal.riderPhone,
          riderLat: _meal.riderLat,
          riderLng: _meal.riderLng,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated window to $selected')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyCustomerError(e, action: 'update delivery window'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSkipFlow() async {
    final skipped = await Navigator.push<bool>(
      context,
      messRoute(
        _SkipConfirmScreen(
          meal: _meal,
          skipAllowance: widget.skipAllowance,
          remainingSkips: _remainingSkips,
        ),
      ),
    );

    if (skipped == true && mounted) {
      setState(() {
        _changed = true;
        _remainingSkips = (_remainingSkips - 1).clamp(0, 99);
        _meal = DailyMealItem(
          id: _meal.id,
          subscriptionId: _meal.subscriptionId,
          providerId: _meal.providerId,
          providerName: _meal.providerName,
          providerPhone: _meal.providerPhone,
          providerLocality: _meal.providerLocality,
          serviceDate: _meal.serviceDate,
          slot: _meal.slot,
          slotLabel: _meal.slotLabel,
          menuSummary: _meal.menuSummary,
          timeWindow: _meal.timeWindow,
          status: 'skipped',
          fulfillmentMode: _meal.fulfillmentMode,
          instructions: _meal.instructions,
          etaMinutes: _meal.etaMinutes,
          cutoffTime: _meal.cutoffTime,
          providerLat: _meal.providerLat,
          providerLng: _meal.providerLng,
          riderName: _meal.riderName,
          riderPhone: _meal.riderPhone,
          riderLat: _meal.riderLat,
          riderLng: _meal.riderLng,
        );
      });
    }
  }

  Future<void> _instructionsSheet() async {
    final ctrl = TextEditingController(text: _meal.instructions);
    final savedText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: ThaliColors.stroke, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delivery & Kitchen Instructions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add gate notes, spice preference, or call-on-arrival instructions.',
              style: TextStyle(fontSize: 13, color: ThaliColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              maxLines: 3,
              maxLength: 160,
              decoration: const InputDecoration(
                hintText: 'Leave at reception or call when arriving...',
              ),
            ),
            const SizedBox(height: 12),
            MessActionButton(
              label: 'Save Instructions',
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            ),
          ],
        ),
      ),
    );

    if (savedText == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final appState = AppStateScope.of(context, listen: false);
      await appState.repository.postMealAction(
        action: 'instruction',
        subscriptionId: _meal.subscriptionId,
        customerId: appState.customerId,
        providerId: _meal.providerId,
        serviceDate: _meal.serviceDate,
        slot: _meal.slot,
        instructions: savedText,
      );
      if (!mounted) return;
      setState(() {
        _changed = true;
        _meal = DailyMealItem(
          id: _meal.id,
          subscriptionId: _meal.subscriptionId,
          providerId: _meal.providerId,
          providerName: _meal.providerName,
          providerPhone: _meal.providerPhone,
          providerLocality: _meal.providerLocality,
          serviceDate: _meal.serviceDate,
          slot: _meal.slot,
          slotLabel: _meal.slotLabel,
          menuSummary: _meal.menuSummary,
          timeWindow: _meal.timeWindow,
          status: _meal.status,
          fulfillmentMode: _meal.fulfillmentMode,
          instructions: savedText,
          etaMinutes: _meal.etaMinutes,
          cutoffTime: _meal.cutoffTime,
          providerLat: _meal.providerLat,
          providerLng: _meal.providerLng,
          riderName: _meal.riderName,
          riderPhone: _meal.riderPhone,
          riderLat: _meal.riderLat,
          riderLng: _meal.riderLng,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instructions sent to kitchen.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyCustomerError(e, action: 'update delivery window'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _callMess() async {
    final phone = _meal.providerPhone.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kitchen contact number is unavailable. Use Chat instead.')),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call $phone')),
      );
    }
  }

  void _reportIssueSheet() {
    final appState = AppStateScope.of(context, listen: false);
    String category = 'Delivery Issue';
    final msgCtrl = TextEditingController();
    bool sending = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: ThaliColors.stroke, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Report Meal Issue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Delivery Issue', 'Missing Item', 'Quality Concern', 'QR / Counter']
                    .map((cat) => ChoiceChip(
                          label: Text(cat),
                          selected: category == cat,
                          selectedColor: ThaliColors.primarySoft,
                          labelStyle: TextStyle(
                            color: category == cat ? ThaliColors.primaryDark : ThaliColors.body,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                          onSelected: (_) => setSheetState(() => category = cat),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: msgCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe the issue for support...',
                ),
              ),
              const SizedBox(height: 14),
              MessActionButton(
                label: 'Submit Issue',
                loading: sending,
                onPressed: () async {
                  final text = msgCtrl.text.trim();
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please describe what happened.')),
                    );
                    return;
                  }
                  setSheetState(() => sending = true);
                  try {
                    final baseUrl = CustomerAuthService.baseUrl;
                    final res = await http.post(
                      Uri.parse('$baseUrl/api/support/ticket'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'name': appState.customerName,
                        'email': appState.customerEmail,
                        'phone': appState.customerPhone.isNotEmpty ? appState.customerPhone : appState.customerId,
                        'role': 'customer',
                        'category': category,
                        'subject': '${_meal.providerName} · ${_meal.slotLabel} (${_meal.serviceDate})',
                        'message': text,
                      }),
                    ).timeout(const Duration(seconds: 12));
                    if (res.statusCode >= 400) {
                      throw Exception('Unable to submit report (${res.statusCode}).');
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Issue submitted to Thali Support.')),
                      );
                    }
                  } catch (e) {
                    setSheetState(() => sending = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(friendlyCustomerError(e, action: 'submit report'))),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final upcoming = widget.allMealsForDay.where((m) => m.id != _meal.id).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: ThaliColors.scaffold,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context, _changed),
            icon: const Icon(Icons.chevron_left_rounded, size: 26),
          ),
          title: Text(_meal.providerName),
        ),
        body: Stack(
          children: [
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
              children: [
                // Top Status + Vector Route Card (Behance MY02)
                CardSurface(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _meal.slotLabel,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                            ),
                            const SizedBox(height: 6),
                            MealStatusBadge(status: _meal.status),
                            const SizedBox(height: 10),
                            if (_meal.menuSummary.isNotEmpty)
                              Text(
                                _meal.menuSummary,
                                style: const TextStyle(fontSize: 12.5, color: ThaliColors.body, height: 1.4),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 13.5, color: ThaliColors.muted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _meal.timeWindow.isNotEmpty ? _meal.timeWindow : 'Scheduled slot',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThaliColors.muted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: PressScale(
                          onTap: () => Navigator.push(
                            context,
                            messRoute(
                              _ExtendedMapScreen(
                                meal: _meal,
                                customerLocation: appState.location,
                              ),
                            ),
                          ),
                          child: Container(
                            height: 112,
                            decoration: BoxDecoration(
                              color: ThaliColors.subtle,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ThaliColors.stroke),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Stack(
                                children: [
                                  const Positioned.fill(
                                    child: CustomPaint(painter: _VectorStreetMapPainter()),
                                  ),
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: ThaliColors.stroke),
                                      ),
                                      child: const Icon(Icons.open_in_full_rounded, size: 12, color: ThaliColors.ink),
                                    ),
                                  ),
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: ThaliColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.storefront_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Progressive Disclosure Management Actions
                CardSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _actionRow(
                        icon: Icons.access_time_rounded,
                        title: 'Reschedule delivery',
                        subtitle: _meal.timeWindow.isNotEmpty ? _meal.timeWindow : 'Select delivery slot',
                        enabled: _canModify,
                        onTap: _rescheduleSheet,
                      ),
                      const Divider(height: 1),
                      _actionRow(
                        icon: Icons.redo_rounded,
                        title: 'Skip meal',
                        subtitle: _canModify
                            ? '$_remainingSkips skip${_remainingSkips == 1 ? '' : 's'} left this week'
                            : 'Meal cannot be skipped in current status',
                        enabled: _canModify,
                        onTap: _openSkipFlow,
                      ),
                      const Divider(height: 1),
                      _actionRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Send instructions to delivery',
                        subtitle: _meal.instructions.isNotEmpty
                            ? _meal.instructions
                            : 'Leave at reception, gate code, etc.',
                        enabled: _canModify,
                        onTap: _instructionsSheet,
                      ),
                    ],
                  ),
                ),

                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const SectionHeader(title: 'Upcoming meals'),
                  const SizedBox(height: 8),
                  ...upcoming.map((other) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CardSurface(
                          onTap: () {
                            setState(() => _meal = other);
                          },
                          padding: const EdgeInsets.all(13),
                          child: Row(
                            children: [
                              FoodGlyph(name: other.slotLabel, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      other.slotLabel,
                                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      other.menuSummary.isNotEmpty ? other.menuSummary : other.timeWindow,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: ThaliColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              MealStatusBadge(status: other.status),
                            ],
                          ),
                        ),
                      )),
                ],

                if (_meal.riderName != null && _meal.riderName!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  CardSurface(
                    borderColor: ThaliColors.green.withValues(alpha: 0.35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ThaliColors.greenSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.delivery_dining_rounded, size: 18, color: ThaliColors.greenDark),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Assigned Delivery Rider', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThaliColors.muted)),
                                  Text(_meal.riderName!, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                                ],
                              ),
                            ),
                            if (_meal.riderPhone != null && _meal.riderPhone!.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.call_rounded, color: ThaliColors.greenDark),
                                tooltip: 'Call rider',
                                onPressed: () => launchUrl(Uri.parse('tel:${_meal.riderPhone}')),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_meal.riderLat != null && _meal.riderLng != null)
                          MessActionButton(
                            label: 'Track Rider Live Pin',
                            height: 40,
                            onPressed: () => launchUrl(
                              Uri.parse('https://www.google.com/maps/search/?api=1&query=${_meal.riderLat},${_meal.riderLng}'),
                              mode: LaunchMode.externalApplication,
                            ),
                          )
                        else
                          Text(
                            _meal.riderPhone != null && _meal.riderPhone!.isNotEmpty
                                ? 'Kitchen self-delivery staff assigned (${_meal.riderPhone}). Live map pin appears once rider enables GPS sharing.'
                                : 'Kitchen self-delivery staff assigned. Live map pin appears once rider starts route.',
                            style: const TextStyle(fontSize: 11.5, color: ThaliColors.muted),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                CardSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _actionRow(
                        icon: Icons.call_outlined,
                        title: 'Call ${_meal.providerName}',
                        subtitle: _meal.providerPhone.isNotEmpty ? _meal.providerPhone : 'Kitchen helpline',
                        enabled: true,
                        onTap: _callMess,
                      ),
                      const Divider(height: 1),
                      _actionRow(
                        icon: Icons.forum_outlined,
                        title: 'Chat with Kitchen',
                        subtitle: 'Message ${_meal.providerName} directly',
                        enabled: true,
                        onTap: () => Navigator.push(
                          context,
                          messRoute(
                            CustomerChatScreen(
                              providerId: _meal.providerId,
                              providerName: _meal.providerName,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      _actionRow(
                        icon: Icons.flag_outlined,
                        title: 'Report an issue',
                        subtitle: 'Delivery delay, missing items, or support',
                        enabled: true,
                        onTap: _reportIssueSheet,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_saving)
              Container(
                color: Colors.black26,
                child: const ThaliLoadingView(label: 'Updating...'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: enabled ? ThaliColors.subtle : ThaliColors.scaffold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: enabled ? ThaliColors.ink : ThaliColors.hint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: enabled ? ThaliColors.ink : ThaliColors.hint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: ThaliColors.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: enabled ? ThaliColors.muted : ThaliColors.hint),
          ],
        ),
      ),
    );
  }
}

class _SkipConfirmScreen extends StatefulWidget {
  const _SkipConfirmScreen({
    required this.meal,
    required this.skipAllowance,
    required this.remainingSkips,
  });

  final DailyMealItem meal;
  final int skipAllowance;
  final int remainingSkips;

  @override
  State<_SkipConfirmScreen> createState() => _SkipConfirmScreenState();
}

class _SkipConfirmScreenState extends State<_SkipConfirmScreen> {
  String _selectedReason = 'Eating out';
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  bool _done = false;

  static const _reasons = ['Eating out', 'Travelling', 'Fasting', 'Not hungry', 'Other'];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmSkip() async {
    setState(() => _submitting = true);
    try {
      final appState = AppStateScope.of(context, listen: false);
      final reasonText = _noteCtrl.text.trim().isNotEmpty
          ? '$_selectedReason: ${_noteCtrl.text.trim()}'
          : _selectedReason;
      await appState.repository.postMealAction(
        action: 'skip',
        subscriptionId: widget.meal.subscriptionId,
        customerId: appState.customerId,
        providerId: widget.meal.providerId,
        serviceDate: widget.meal.serviceDate,
        slot: widget.meal.slot,
        reason: reasonText,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyCustomerError(e, action: 'skip meal'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      // Behance Emerald Confirmation Screen (MY05)
      return Scaffold(
        backgroundColor: ThaliColors.green,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded, size: 46, color: ThaliColors.green),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Meal Skipped',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.meal.slotLabel} at ${widget.meal.providerName} on ${widget.meal.serviceDate} has been marked skipped.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.92), height: 1.45),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ThaliColors.greenDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(title: const Text('Skip Meal')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          CardSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.meal.slotLabel} · ${widget.meal.providerName}',
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.meal.serviceDate} · ${widget.meal.timeWindow}',
                  style: const TextStyle(fontSize: 13, color: ThaliColors.muted),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThaliColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: ThaliColors.primaryDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.remainingSkips} of ${widget.skipAllowance} weekly skips remaining.${widget.meal.cutoffTime.isNotEmpty ? ' Cutoff: ${widget.meal.cutoffTime}.' : ''}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ThaliColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Reason for skipping',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ThaliColors.ink),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons.map((r) {
              final active = _selectedReason == r;
              return ChoiceChip(
                label: Text(r),
                selected: active,
                selectedColor: ThaliColors.primarySoft,
                backgroundColor: ThaliColors.card,
                side: BorderSide(color: active ? ThaliColors.primary : ThaliColors.stroke),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: active ? ThaliColors.primaryDark : ThaliColors.body,
                ),
                onSelected: (_) => setState(() => _selectedReason = r),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Optional note for kitchen...'),
          ),
          const SizedBox(height: 22),
          MessActionButton(
            label: 'Confirm Skip',
            loading: _submitting,
            onPressed: widget.remainingSkips > 0 ? _confirmSkip : null,
          ),
          if (widget.remainingSkips <= 0)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'You have used all weekly skips on this plan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: ThaliColors.red, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExtendedMapScreen extends StatelessWidget {
  const _ExtendedMapScreen({required this.meal, required this.customerLocation});
  final DailyMealItem meal;
  final String customerLocation;

  @override
  Widget build(BuildContext context) {
    final st = meal.status.toLowerCase();
    final stepIndex = st == 'delivered' || st == 'redeemed'
        ? 3
        : (st == 'out_for_delivery' || st == 'ready_at_counter')
            ? 2
            : st == 'preparing'
                ? 1
                : 0;

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(title: Text('${meal.slotLabel} Tracking')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThaliColors.green,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.etaMinutes != null
                      ? 'Estimated arrival in ${meal.etaMinutes} mins'
                      : meal.providerName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${meal.slotLabel} · ${meal.timeWindow}',
                  style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CardSurface(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: CustomPaint(painter: _VectorStreetMapPainter()),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 14,
                      right: 16,
                      child: CardSurface(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: ThaliColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${meal.providerName}${meal.providerLocality.isNotEmpty ? ' · ${meal.providerLocality}' : ''}${customerLocation.isNotEmpty ? ' -> $customerLocation' : ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                                  ),
                                  if (meal.riderLat != null && meal.riderLng != null)
                                    Text(
                                      'Live rider GPS: ${meal.riderLat!.toStringAsFixed(4)}, ${meal.riderLng!.toStringAsFixed(4)}',
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: ThaliColors.green),
                                    ),
                                ],
                              ),
                            ),
                            if (meal.riderLat != null && meal.riderLng != null)
                              TextButton(
                                onPressed: () => launchUrl(
                                  Uri.parse('https://www.google.com/maps/search/?api=1&query=${meal.riderLat},${meal.riderLng}'),
                                  mode: LaunchMode.externalApplication,
                                ),
                                child: const Text('Maps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThaliColors.primary)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          CardSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Meal Progress',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                ),
                const SizedBox(height: 14),
                _timelineStep('Scheduled', 'Meal confirmed in kitchen queue', stepIndex >= 0),
                _timelineStep('Preparing', 'Fresh home-style cooking in progress', stepIndex >= 1),
                _timelineStep(
                  meal.fulfillmentMode.toLowerCase().contains('pickup') ? 'Ready at Counter' : 'Out for Delivery',
                  meal.fulfillmentMode.toLowerCase().contains('pickup')
                      ? 'Scan Counter QR to collect meal'
                      : 'Tiffin dispatched for delivery',
                  stepIndex >= 2,
                ),
                _timelineStep('Completed', 'Meal delivered or checked in', stepIndex >= 3, isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineStep(String title, String sub, bool done, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: done ? ThaliColors.green : ThaliColors.subtle,
                shape: BoxShape.circle,
                border: Border.all(color: done ? ThaliColors.green : ThaliColors.stroke),
              ),
              child: done ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: done ? ThaliColors.greenBorder : ThaliColors.stroke,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: done ? ThaliColors.ink : ThaliColors.muted,
                  ),
                ),
                Text(sub, style: const TextStyle(fontSize: 12, color: ThaliColors.muted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VectorStreetMapPainter extends CustomPainter {
  const _VectorStreetMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFF3F4F6);
    canvas.drawRect(Offset.zero & size, bg);

    final blockPaint = Paint()..color = const Color(0xFFE5E7EB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.1, size.height * 0.14, size.width * 0.25, size.height * 0.24), const Radius.circular(6)),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.54, size.height * 0.12, size.width * 0.32, size.height * 0.26), const Radius.circular(6)),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.14, size.height * 0.56, size.width * 0.34, size.height * 0.26), const Radius.circular(6)),
      blockPaint,
    );

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;
    final roadPath = Path()
      ..moveTo(0, size.height * 0.48)
      ..quadraticBezierTo(size.width * 0.45, size.height * 0.38, size.width, size.height * 0.54);
    canvas.drawPath(roadPath, road);

    final vRoad = Path()
      ..moveTo(size.width * 0.46, 0)
      ..lineTo(size.width * 0.52, size.height);
    canvas.drawPath(vRoad, road);

    final route = Paint()
      ..color = ThaliColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final routePath = Path()
      ..moveTo(size.width * 0.24, size.height * 0.44)
      ..quadraticBezierTo(size.width * 0.45, size.height * 0.38, size.width * 0.68, size.height * 0.5);
    canvas.drawPath(routePath, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
