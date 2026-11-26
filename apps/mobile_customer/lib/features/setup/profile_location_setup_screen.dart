import 'package:flutter/material.dart';

import '../../core/repositories/mess_repository.dart';
import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../../mess_app.dart';

/// Complete your profile (Step 1) -> Location Search (Step 2) -> Confirm Pin Map (Step 3).
class ProfileLocationSetupScreen extends StatefulWidget {
  const ProfileLocationSetupScreen({super.key, this.locationOnly = false});
  final bool locationOnly;

  @override
  State<ProfileLocationSetupScreen> createState() => _ProfileLocationSetupScreenState();
}

class _ProfileLocationSetupScreenState extends State<ProfileLocationSetupScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();

  late int _step; // 0 = profile, 1 = location search, 2 = map pin confirm
  String _foodPref = 'veg';
  bool _loadingLocations = false;
  bool _saving = false;
  List<Map<String, dynamic>> _predictions = [];

  String _selectedLocality = '';
  String _selectedCity = '';
  String _selectedFormatted = '';
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _step = widget.locationOnly ? 1 : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = AppStateScope.of(context);
      if (s.customerName.isNotEmpty) _nameController.text = s.customerName;
      if (s.foodPreference.isNotEmpty) _foodPref = s.foodPreference;
      if (s.location.isNotEmpty) {
        _selectedLocality = s.location;
        _selectedCity = s.selectedCity;
      }
      _runSearch('');
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    setState(() => _loadingLocations = true);
    try {
      final list = await AppStateScope.of(context).repository.searchLocations(query);
      if (!mounted) return;
      setState(() => _predictions = list);
    } finally {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  Future<void> _confirmAndSave() async {
    setState(() => _saving = true);
    try {
      final state = AppStateScope.of(context);
      final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : state.customerName;
      final loc = _selectedLocality.isNotEmpty ? _selectedLocality : _searchController.text.trim();
      final city = _selectedCity.isNotEmpty ? _selectedCity : loc;
      if (widget.locationOnly) {
        state.updateLocation(loc, city: city, lat: _lat, lng: _lng);
        if (state.customerId.isNotEmpty) {
          await state.repository.saveProfile(
            userId: state.customerId,
            locality: loc,
            city: city,
            address: _selectedFormatted.isNotEmpty ? _selectedFormatted : loc,
            latitude: _lat,
            longitude: _lng,
          );
        }
        if (mounted) Navigator.pop(context, true);
      } else {
        await state.completeProfileAndLocation(
          name: name,
          foodPref: _foodPref,
          locality: loc,
          city: city,
          address: _selectedFormatted,
          lat: _lat,
          lng: _lng,
        );
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            messRoute(const MessRootGate()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyCustomerError(e, action: 'save location'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Complete your profile', 'Location', 'Confirm delivery location'];
    return Scaffold(
      backgroundColor: ThaliColors.card,
      appBar: AppBar(
        leading: (_step > (widget.locationOnly ? 1 : 0) || widget.locationOnly)
            ? IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 26),
                onPressed: () {
                  if (_step > (widget.locationOnly ? 1 : 0)) {
                    setState(() => _step--);
                  } else {
                    Navigator.maybePop(context);
                  }
                },
              )
            : null,
        title: Text(titles[_step]),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: SafeArea(
        child: _step == 0
            ? _buildProfileStep()
            : (_step == 1 ? _buildLocationSearchStep() : _buildMapConfirmStep()),
      ),
    );
  }

  Widget _buildProfileStep() {
    final ready = _nameController.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('What should we call you?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Enter your nickname or full name'),
          ),
          const SizedBox(height: 22),
          const Text("What's your food preference?", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
          const SizedBox(height: 12),
          Row(
            children: [
              _PrefPill(
                label: 'Veg',
                isVeg: true,
                selected: _foodPref == 'veg',
                onTap: () => setState(() => _foodPref = 'veg'),
              ),
              const SizedBox(width: 12),
              _PrefPill(
                label: 'Non Veg',
                isVeg: false,
                selected: _foodPref == 'non_veg',
                onTap: () => setState(() => _foodPref = 'non_veg'),
              ),
            ],
          ),
          const Spacer(),
          MessActionButton(
            label: 'Continue',
            onPressed: ready ? () => setState(() => _step = 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSearchStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Enter your area or apartment name', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (v) {
              setState(() {});
              _runSearch(v);
            },
            decoration: InputDecoration(
              hintText: 'Search location or apartment',
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: ThaliColors.muted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _runSearch('');
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              final q = _searchController.text.trim();
              if (q.isNotEmpty) {
                setState(() {
                  _selectedLocality = q.split(',').first.trim();
                  _selectedCity = q.split(',').length > 1 ? q.split(',')[1].trim() : q;
                  _selectedFormatted = q;
                  _step = 2;
                });
              } else if (_predictions.isNotEmpty) {
                final first = _predictions.first;
                setState(() {
                  _selectedLocality = first['main_text']?.toString() ?? first['description'].toString();
                  _selectedCity = first['secondary_text']?.toString() ?? '';
                  _selectedFormatted = first['description']?.toString() ?? '';
                  _lat = (first['latitude'] as num?)?.toDouble();
                  _lng = (first['longitude'] as num?)?.toDouble();
                  _step = 2;
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: const [
                  Icon(Icons.my_location_rounded, size: 18, color: ThaliColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Use selected or nearby service area', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ThaliColors.primary)),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: ThaliColors.muted),
                ],
              ),
            ),
          ),
          const Divider(),
          const SizedBox(height: 10),
          const Text('SEARCH RESULTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThaliColors.hint, letterSpacing: 0.7)),
          const SizedBox(height: 6),
          Expanded(
            child: _loadingLocations
                ? const ThaliLoadingView(label: 'Searching places...')
                : _predictions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Type any area, locality, or city in India', style: TextStyle(fontSize: 13, color: ThaliColors.muted)),
                            if (_searchController.text.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: () => setState(() {
                                  _selectedLocality = _searchController.text.trim();
                                  _selectedCity = _searchController.text.trim();
                                  _selectedFormatted = _searchController.text.trim();
                                  _step = 2;
                                }),
                                child: Text('Use "${_searchController.text.trim()}"'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _predictions.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, i) {
                          final item = _predictions[i];
                          final main = item['main_text']?.toString() ?? item['description']?.toString() ?? '';
                          final sub = item['secondary_text']?.toString() ?? '';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.location_on_outlined, color: ThaliColors.ink),
                            title: Text(main, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                            subtitle: sub.isNotEmpty ? Text(sub, style: const TextStyle(fontSize: 12, color: ThaliColors.muted)) : null,
                            onTap: () {
                              setState(() {
                                _selectedLocality = main;
                                _selectedCity = sub.split(',').first.trim();
                                _selectedFormatted = item['description']?.toString() ?? main;
                                _lat = (item['latitude'] as num?)?.toDouble();
                                _lng = (item['longitude'] as num?)?.toDouble();
                                _step = 2;
                              });
                            },
                          );
                        },
                      ),
          ),
          MessActionButton(
            label: 'Continue',
            onPressed: _searchController.text.trim().isNotEmpty || _selectedLocality.isNotEmpty
                ? () {
                    if (_selectedLocality.isEmpty) {
                      _selectedLocality = _searchController.text.trim();
                      _selectedCity = _searchController.text.trim();
                      _selectedFormatted = _searchController.text.trim();
                    }
                    setState(() => _step = 2);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMapConfirmStep() {
    final shownLoc = _selectedLocality.isNotEmpty ? _selectedLocality : 'Selected Area';
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              CustomPaint(
                painter: _VectorStreetMapPainter(),
                size: Size.infinite,
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: ThaliColors.ink,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          Text('Delivering to $shownLoc', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                          const Text('Tap change below to pick another area', style: TextStyle(fontSize: 10, color: Color(0xFFD4D4D8))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: ThaliColors.primary.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.location_on_rounded, size: 34, color: ThaliColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: const BoxDecoration(
            color: ThaliColors.card,
            border: Border(top: BorderSide(color: ThaliColors.stroke)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('DELIVERY LOCATION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ThaliColors.muted, letterSpacing: 0.7)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 22, color: ThaliColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shownLoc, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                        if (_selectedFormatted.isNotEmpty && _selectedFormatted != shownLoc)
                          Text(_selectedFormatted, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: ThaliColors.muted)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _step = 1),
                    child: const Text('CHANGE', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: ThaliColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              MessActionButton(
                label: 'Confirm Location',
                loading: _saving,
                onPressed: _confirmAndSave,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrefPill extends StatelessWidget {
  const _PrefPill({required this.label, required this.isVeg, required this.selected, required this.onTap});
  final String label;
  final bool isVeg;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bd = selected ? (isVeg ? ThaliColors.green : ThaliColors.primaryPressed) : ThaliColors.stroke;
    final bg = selected ? (isVeg ? ThaliColors.greenSoft : ThaliColors.primarySoft) : ThaliColors.card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99), border: Border.all(color: bd, width: selected ? 1.5 : 1)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            VegIndicator(isVeg: isVeg, size: 15),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: selected ? bd : ThaliColors.ink)),
          ],
        ),
      ),
    );
  }
}

class _VectorStreetMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF3F4F6));
    final blockPaint = Paint()..color = const Color(0xFFE5E7EB);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.14, size.height * 0.16, 95, 65), const Radius.circular(8)), blockPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.56, size.height * 0.58, 120, 74), const Radius.circular(8)), blockPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.08, size.height * 0.62, 72, 54), const Radius.circular(8)), Paint()..color = const Color(0xFFDCFCE7));

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.34), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.62), Offset(size.width, size.height * 0.52), roadPaint);
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.42, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.78, 0), Offset(size.width * 0.68, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
