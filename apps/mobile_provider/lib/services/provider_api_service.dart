import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProviderSession {
  ProviderSession({
    required this.token,
    required this.userId,
    required this.email,
    required this.providerId,
    required this.businessName,
  });

  final String token;
  final String userId;
  final String email;
  final String providerId;
  final String businessName;

  Map<String, dynamic> toJson() => {
    'token': token,
    'userId': userId,
    'email': email,
    'providerId': providerId,
    'businessName': businessName,
  };

  factory ProviderSession.fromJson(Map<String, dynamic> json) => ProviderSession(
    token: json['token'] as String? ?? '',
    userId: json['userId'] as String? ?? '',
    email: json['email'] as String? ?? '',
    providerId: json['providerId'] as String? ?? '',
    businessName: json['businessName'] as String? ?? '',
  );
}

class DashboardMetrics {
  DashboardMetrics({
    required this.todayScans,
    required this.totalScans,
    required this.unbilledScans,
    required this.activeSubscribers,
    required this.activePlans,
    required this.currentSlot,
    required this.todayDate,
    required this.recentRedemptions,
  });

  final int todayScans;
  final int totalScans;
  final int unbilledScans;
  final int activeSubscribers;
  final int activePlans;
  final String currentSlot;
  final String todayDate;
  final List<Map<String, dynamic>> recentRedemptions;
}

class ProviderApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mess-beta.vercel.app',
  );

  static ProviderSession? currentSession;
  static const String _sessionKey = 'mess_provider_saved_session';

  static Future<void> saveSession(ProviderSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
      currentSession = session;
    } catch (_) {}
  }

  static Future<ProviderSession?> loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_sessionKey);
      if (str != null && str.isNotEmpty) {
        final json = jsonDecode(str) as Map<String, dynamic>;
        final session = ProviderSession.fromJson(json);
        currentSession = session;
        return session;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      currentSession = null;
    } catch (_) {}
  }

  static Future<ProviderSession> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/login');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
            'role': 'provider',
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      final user = data['user'] as Map<String, dynamic>? ?? {};
      final provider = data['provider'] as Map<String, dynamic>?;
      final providerId = user['provider_id'] ?? provider?['id'];
      final businessName = user['provider_name'] ?? provider?['display_name'] ?? 'My Mess';

      if (providerId == null || providerId.toString().isEmpty) {
        throw Exception('No approved mess found for this login. Please register your mess and await admin approval.');
      }

      final session = ProviderSession(
        token: data['token'] as String? ?? '',
        userId: user['id'] as String? ?? 'usr-provider',
        email: email.trim(),
        providerId: providerId.toString(),
        businessName: businessName.toString(),
      );
      await saveSession(session);
      return session;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'Login failed. Please verify credentials.');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchApprovedProviders() async {
    try {
      final uri = Uri.parse('$baseUrl/api/providers');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data is Map && data['providers'] is List)
            ? (data['providers'] as List)
            : (data is List ? data : []);
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<ProviderSession> register({
    required String businessName,
    required String ownerName,
    required String phone,
    required String email,
    required String password,
    required String address,
    required String city,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/register');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim().isNotEmpty ? email.trim() : '${businessName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}@mess.in',
            'password': password.isNotEmpty ? password : 'ProviderPass@123',
            'role': 'provider',
            'business_name': businessName.trim(),
            'name': ownerName.trim(),
            'phone': phone.trim(),
            'address': address.trim(),
            'city': city.trim(),
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      final user = data['user'] as Map<String, dynamic>? ?? {};
      final provider = data['provider'] as Map<String, dynamic>?;
      final providerId = user['provider_id'] ?? provider?['id'] ?? 'prov-new';
      final name = user['provider_name'] ?? provider?['display_name'] ?? businessName;

      final session = ProviderSession(
        token: data['token'] as String? ?? '',
        userId: user['id'] as String? ?? 'usr-provider',
        email: email.trim(),
        providerId: providerId.toString(),
        businessName: name.toString(),
      );
      await saveSession(session);
      return session;
    } else {
      throw Exception(data['error'] ?? data['message'] ?? 'Registration failed. Please check inputs.');
    }
  }

  static Future<DashboardMetrics> fetchDashboard(String providerId) async {
    final uri = Uri.parse('$baseUrl/api/provider/dashboard?provider_id=$providerId');
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
      final redemptions = (data['today_redemptions'] as List<dynamic>? ?? [])
          .map((item) => item as Map<String, dynamic>)
          .toList();

      return DashboardMetrics(
        todayScans: (metrics['today_scans_count'] as num?)?.toInt() ?? 0,
        totalScans: (metrics['total_scans'] as num?)?.toInt() ?? 0,
        unbilledScans: (metrics['unbilled_scans'] as num?)?.toInt() ?? 0,
        activeSubscribers: (metrics['active_subscribers'] as num?)?.toInt() ?? 0,
        activePlans: (metrics['active_plans_count'] as num?)?.toInt() ?? 0,
        currentSlot: (data['current_slot'] as String?) ?? 'LUNCH',
        todayDate: (data['today_date'] as String?) ?? '',
        recentRedemptions: redemptions,
      );
    }
    throw Exception('Failed to load dashboard metrics.');
  }

  static Future<String> fetchDailyQrToken(String providerId, {String? slot}) async {
    final slotQuery = slot != null ? '&slot=$slot' : '';
    final uri = Uri.parse('$baseUrl/api/provider/qr/generate?provider_id=$providerId$slotQuery');
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['token'] as String?) ?? '';
    }
    throw Exception('Failed to generate daily QR token.');
  }

  static Future<List<Map<String, dynamic>>> fetchSubscribers(String providerId) async {
    final uri = Uri.parse('$baseUrl/api/provider/subscriptions?provider_id=$providerId');
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['subscriptions'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      return list;
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchAttendance(String providerId, {String? date}) async {
    final dateQuery = date != null ? '&date=$date' : '';
    final uri = Uri.parse('$baseUrl/api/provider/redemptions?provider_id=$providerId$dateQuery');
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['redemptions'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      return list;
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchProviderPlans(String providerId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/provider/plans?provider_id=$providerId');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data is Map && data['plans'] is List)
            ? (data['plans'] as List)
            : [];
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> createManualSubscriber({
    required String providerId,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String? planId,
    String paymentMode = 'cash',
    double? amountPaid,
    int? customDays,
    int? customCredits,
    String? notes,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/subscribers/manual');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'provider_id': providerId,
            'customer_name': customerName.trim(),
            'customer_phone': customerPhone.trim(),
            if (customerEmail != null && customerEmail.isNotEmpty) 'customer_email': customerEmail.trim(),
            if (planId != null && planId.isNotEmpty) 'plan_id': planId,
            'payment_mode': paymentMode,
            if (amountPaid != null) 'amount_paid_inr': amountPaid,
            if (customDays != null) 'custom_days': customDays,
            if (customCredits != null) 'custom_credits': customCredits,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return data;
    }
    throw Exception(data['error'] ?? 'Failed to add manual member.');
  }

  static Future<Map<String, dynamic>> reactivateSubscription({
    required String providerId,
    required String subscriptionId,
    String action = 'renew',
    int days = 30,
    int credits = 30,
    String paymentMode = 'cash',
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/subscribers/reactivate');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'provider_id': providerId,
            'subscription_id': subscriptionId,
            'action': action,
            'days': days,
            'credits': credits,
            'payment_mode': paymentMode,
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return data;
    }
    throw Exception(data['error'] ?? 'Failed to renew subscription.');
  }

  static Future<List<Map<String, dynamic>>> fetchSubscriberHistory(String providerId, String subscriberId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/provider/subscribers/$subscriberId/history?provider_id=$providerId');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['history'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
        return list;
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> fetchMenu(String providerId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/provider/menu?provider_id=$providerId');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final menuList = (data['menus'] as List<dynamic>? ?? data['menu'] as List<dynamic>? ?? []);
        return {'menus': menuList, 'menu': menuList};
      }
    } catch (_) {}
    return {'menus': [], 'menu': []};
  }

  static Future<void> addMenuItem({
    required String providerId,
    required String name,
    required String slot,
    int price = 0,
    bool isExtra = false,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/menu');
    await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider_id': providerId,
        'action': 'add_item',
        'name': name,
        'item_name': name,
        'slot': slot.toLowerCase(),
        'price': price,
        'is_extra': isExtra,
      }),
    ).timeout(const Duration(seconds: 10));
  }

  static Future<void> removeMenuItem({
    required String providerId,
    required String name,
    required String slot,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/menu');
    await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider_id': providerId,
        'action': 'remove_item',
        'name': name,
        'item_name': name,
        'slot': slot.toLowerCase(),
      }),
    ).timeout(const Duration(seconds: 10));
  }

  static Future<void> toggleMenuAvailability({
    required String providerId,
    required String name,
    required bool isAvailable,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/menu');
    await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider_id': providerId,
        'action': 'toggle_availability',
        'name': name,
        'item_name': name,
        'is_available': isAvailable,
      }),
    ).timeout(const Duration(seconds: 10));
  }

  static Future<void> savePlan({
    required String providerId,
    String? planId,
    required String name,
    required String description,
    required String planType,
    required int durationDays,
    required int priceInr,
    int? mealCredits,
    int? discountPercent,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/plan');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider_id': providerId,
        if (planId != null) 'id': planId,
        'name': name,
        'description': description,
        'plan_type': planType,
        'duration_days': durationDays,
        'price_inr': priceInr,
        if (mealCredits != null) 'meal_credits': mealCredits,
        if (discountPercent != null) 'discount_percent': discountPercent,
      }),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to save plan');
    }
  }

  static Future<void> deletePlan({
    required String providerId,
    required String planId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/plan?provider_id=$providerId&plan_id=$planId');
    await http.delete(uri).timeout(const Duration(seconds: 10));
  }

  static Future<List<Map<String, dynamic>>> fetchOrders(String providerId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/provider/orders?provider_id=$providerId');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['orders'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
        return list;
      }
    } catch (_) {}
    return [];
  }

  static Future<void> createOrder({
    required String providerId,
    required String customerName,
    String? customerPhone,
    required String itemsSummary,
    required double totalAmount,
    String paymentMode = 'cash',
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/orders');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider_id': providerId,
        'customer_name': customerName,
        'customer_phone': customerPhone ?? '',
        'items_summary': itemsSummary,
        'total_amount_inr': totalAmount,
        'payment_mode': paymentMode,
      }),
    ).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to record order');
    }
  }

  static Future<Map<String, dynamic>> fetchTimings(String providerId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/provider/timings?provider_id=$providerId');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['timings'] as Map<String, dynamic>? ?? {};
      }
    } catch (_) {}
    return {};
  }

  static Future<void> updateTimings({
    required String providerId,
    required Map<String, dynamic> timings,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/timings');
    await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider_id': providerId,
        ...timings,
      }),
    ).timeout(const Duration(seconds: 10));
  }

  static Future<void> submitSupportTicket({
    required String name,
    required String email,
    required String phone,
    required String role,
    required String subject,
    required String message,
    String category = 'general',
  }) async {
    final uri = Uri.parse('$baseUrl/api/support/ticket');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'subject': subject,
        'message': message,
        'category': category,
      }),
    ).timeout(const Duration(seconds: 12));
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to submit support ticket');
    }
  }

  static Future<bool> fetchKitchenStatus(String providerId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/provider/status?provider_id=$providerId');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['is_open_today'] as bool?) ?? true;
      }
    } catch (_) {}
    return true;
  }

  static Future<bool> toggleKitchenStatus({
    required String providerId,
    required bool isOpen,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/provider/status');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'provider_id': providerId,
              'is_open': isOpen,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
    } catch (_) {}
    return false;
  }
}
