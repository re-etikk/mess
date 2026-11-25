import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ProviderApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://www.thali.store',
  );
  static const String supabaseUrl = 'https://mrbtwsrknqofjkrbssww.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yYnR3c3JrbnFvZmprcmJzc3d3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5MzEzNDcsImV4cCI6MjEwODUwNzM0N30.TzKjZ593n_ku_81ZCAuzOkeHl-7pGmQjylzIP3cHssc';

  static String friendlyError(
    Object error, {
    int? statusCode,
    String? body,
    String action = 'load data',
  }) {
    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('clientexception')) {
      return 'No internet connection or unable to reach Thali servers right now. Check your network and pull down to retry.';
    }
    if (lower.contains('timeoutexception') || lower.contains('timed out')) {
      return 'Server took too long to respond while trying to $action. Pull down to retry.';
    }

    final bodyTrim = (body ?? '').trimLeft().toLowerCase();
    if (statusCode == 404 ||
        lower.contains('formatexception') ||
        bodyTrim.startsWith('<!doctype') ||
        bodyTrim.startsWith('<html')) {
      if (statusCode == 404) {
        return 'This feature is not live on thali.store yet (404). Redeploy the web backend to enable $action.';
      }
      return 'Could not $action because the server returned a web page instead of app data. Please redeploy the web backend.';
    }
    if (statusCode == 401) {
      return 'Your partner session expired. Please sign in again.';
    }
    if (statusCode == 403) {
      return 'You do not have permission for this kitchen action.';
    }
    if (statusCode == 503) {
      return 'Database table or server credentials are not configured yet on the backend.';
    }
    if (raw.startsWith('Exception: ')) {
      final clean = raw.substring(11).trim();
      if (clean.toLowerCase().contains('persisted provider review table')) {
        return 'Reviews table is missing in Supabase or the web update is not deployed yet. Run the SQL migration and redeploy.';
      }
      return clean;
    }
    return 'Unable to $action right now. Pull down to refresh.';
  }

  static Map<String, dynamic> _decodeResponse(http.Response response, {String action = 'load data'}) {
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw Exception('The server redirected the request while trying to $action. Please update the app.');
    }
    final trimmed = response.body.trimLeft().toLowerCase();
    if (response.statusCode == 404 || trimmed.startsWith('<!doctype') || trimmed.startsWith('<html')) {
      throw Exception(friendlyError('HTML/404', statusCode: response.statusCode, body: response.body, action: action));
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException catch (e) {
      throw Exception(friendlyError(e, statusCode: response.statusCode, body: response.body, action: action));
    }
    throw Exception('Server could not process $action (HTTP ${response.statusCode}). Please try again.');
  }

  static ProviderSession? currentSession;
  static const String _sessionKey = 'mess_provider_saved_session';

  static Map<String, String> _authHeaders({bool json = false}) => {
    if (json) 'Content-Type': 'application/json',
    if (currentSession?.token.isNotEmpty == true) 'Authorization': 'Bearer ${currentSession!.token}',
  };

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
        if (session.refreshToken.isNotEmpty) {
          try {
            final refreshed = await refreshSession(session.refreshToken);
            await saveSession(refreshed);
            return refreshed;
          } catch (_) {
            if (session.token.isEmpty) return null;
          }
        }
        return session.token.isEmpty ? null : session;
      }
    } catch (_) {}
    return null;
  }

  static Future<ProviderSession> refreshSession(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    ).timeout(const Duration(seconds: 12));
    final data = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
      throw Exception(data['error'] ?? 'Session refresh failed.');
    }
    final previous = currentSession;
    final user = data['user'] as Map<String, dynamic>? ?? {};
    final refreshedSession = ProviderSession(
      token: data['token']?.toString() ?? '',
      refreshToken: data['refresh_token']?.toString() ?? refreshToken,
      userId: user['id']?.toString() ?? previous?.userId ?? '',
      email: user['email']?.toString() ?? previous?.email ?? '',
      providerId: previous?.providerId ?? '',
      businessName: previous?.businessName ?? 'My Mess',
    );
    await saveSession(refreshedSession);
    return refreshedSession;
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
          headers: _authHeaders(json: true),
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
            'role': 'provider',
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = _decodeResponse(response);
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
        refreshToken: data['refresh_token'] as String? ?? '',
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
      final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
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
    bool supportsDelivery = false,
    bool supportsPickup = true,
  }) async {
    if (!email.trim().contains('@') || password.trim().length < 6) {
      throw Exception('Valid partner email and password (min 6 characters) are required.');
    }
    final uri = Uri.parse('$baseUrl/api/provider/register');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _authHeaders(json: true),
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
              'business_name': businessName.trim(),
              'name': ownerName.trim(),
              'phone': phone.trim(),
              'address': address.trim(),
              'city': city.trim(),
              'supports_delivery': supportsDelivery,
              'supports_pickup': supportsPickup,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception(friendlyError(e, action: 'register your kitchen'));
    }

    final data = _decodeResponse(response, action: 'register your kitchen');
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
    final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 12));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
      final redemptions = (data['today_redemptions'] as List<dynamic>? ?? [])
          .map((item) => item as Map<String, dynamic>)
          .toList();

      int activePlansCount = (metrics['active_plans_count'] as num?)?.toInt() ?? 0;
      if (activePlansCount == 0) {
        try {
          const supabaseUrl = 'https://mrbtwsrknqofjkrbssww.supabase.co';
          const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yYnR3c3JrbnFvZmprcmJzc3d3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5MzEzNDcsImV4cCI6MjEwODUwNzM0N30.TzKjZ593n_ku_81ZCAuzOkeHl-7pGmQjylzIP3cHssc';
          final pRes = await http.get(
            Uri.parse('$supabaseUrl/rest/v1/subscription_plans?provider_id=eq.$providerId&active=eq.true&select=id'),
            headers: {'apikey': supabaseKey, 'Authorization': 'Bearer $supabaseKey'},
          ).timeout(const Duration(seconds: 5));
          if (pRes.statusCode == 200) {
            final pList = jsonDecode(pRes.body) as List<dynamic>;
            if (pList.isNotEmpty) activePlansCount = pList.length;
          }
        } catch (_) {}
      }

      final providerObj = data['provider'] as Map<String, dynamic>? ?? {};
      final rawAvg = metrics['average_rating'];
      return DashboardMetrics(
        todayScans: (metrics['today_scans_count'] as num?)?.toInt() ?? 0,
        totalScans: (metrics['total_scans'] as num?)?.toInt() ?? 0,
        unbilledScans: (metrics['unbilled_scans'] as num?)?.toInt() ?? 0,
        activeSubscribers: (metrics['active_subscribers'] as num?)?.toInt() ?? 0,
        activePlans: activePlansCount,
        currentSlot: (data['current_slot'] as String?) ?? 'LUNCH',
        todayDate: (data['today_date'] as String?) ?? '',
        recentRedemptions: redemptions,
        pendingCashCount: (metrics['pending_cash_count'] as num?)?.toInt() ?? 0,
        pendingCashInr: (metrics['pending_cash_inr'] as num?)?.toInt() ?? 0,
        onlineSettledInr: (metrics['online_settled_inr'] as num?)?.toInt() ?? 0,
        averageRating: rawAvg != null ? (rawAvg as num).toDouble() : null,
        reviewsCount: (metrics['reviews_count'] as num?)?.toInt() ?? 0,
        locality: providerObj['locality']?.toString() ?? '',
        city: providerObj['city']?.toString() ?? '',
      );
    }
    final data = _decodeResponse(response);
    throw Exception(data['error'] ?? 'Failed to load dashboard metrics (HTTP ${response.statusCode}).');
  }

  static Future<String> fetchDailyQrToken(String providerId, {String? slot, String? token}) async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final slotVal = (slot != null && slot.isNotEmpty)
        ? slot.toUpperCase()
        : (now.hour < 11 ? 'BREAKFAST' : (now.hour < 16 ? 'LUNCH' : 'DINNER'));

    try {
      final slotQuery = '&slot=$slotVal';
      final uri = Uri.parse('$baseUrl/api/provider/qr/generate?provider_id=$providerId$slotQuery');
      String? authToken = (token != null && token.isNotEmpty) ? token : currentSession?.token;

      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tok = (data['token'] as String?) ?? '';
        if (tok.isNotEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('daily_qr_token_$providerId', tok);
            await prefs.setString('daily_qr_date_$providerId', todayStr);
          } catch (_) {}
          return tok;
        }
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString('daily_qr_date_$providerId');
      if (savedDate == todayStr) {
        final cached = prefs.getString('daily_qr_token_$providerId');
        if (cached != null && cached.isNotEmpty) return cached;
      }
    } catch (_) {}

    return 'MESS_QR|$providerId|$todayStr|$slotVal|${now.millisecondsSinceEpoch}|${now.millisecondsSinceEpoch + 1800000}|auth_valid';
  }

  static Future<List<Map<String, dynamic>>> fetchPendingSubscriptions(String providerId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/provider/subscriptions/pending?provider_id=$providerId');
      final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['pending'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> approveSubscription({
    required String providerId,
    required String subscriptionId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/subscriptions/approve');
    final response = await http.post(
      uri,
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'provider_id': providerId,
        'subscription_id': subscriptionId,
      }),
    ).timeout(const Duration(seconds: 12));

    final data = _decodeResponse(response);
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to approve subscription');
    }
  }

  static Future<void> rejectSubscription({
    required String providerId,
    required String subscriptionId,
    String? reason,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/subscriptions/reject');
    final response = await http.post(
      uri,
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'provider_id': providerId,
        'subscription_id': subscriptionId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      }),
    ).timeout(const Duration(seconds: 12));

    final data = _decodeResponse(response);
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to reject subscription');
    }
  }

  static Future<Map<String, dynamic>> fetchPaymentSettings(String providerId) async {
    Map<String, dynamic> localCached = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('thali_provider_payment_settings_$providerId');
      if (raw != null && raw.isNotEmpty) {
        localCached = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}

    try {
      final uri = Uri.parse('$baseUrl/api/provider/payment-settings?provider_id=$providerId');
      final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final serverSettings = data['settings'] as Map<String, dynamic>? ?? {};
        if (serverSettings['upi_id'] != null && serverSettings['upi_id'].toString().isNotEmpty) {
          final merged = {...localCached, ...serverSettings};
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('thali_provider_payment_settings_$providerId', jsonEncode(merged));
          } catch (_) {}
          return merged;
        }
      }
    } catch (_) {}

    if (localCached.isNotEmpty) return localCached;
    return {'upi_id': '', 'upi_name': '', 'upi_qr_url': ''};
  }

  static Future<void> savePaymentSettings({
    required String providerId,
    required String upiId,
    required String upiName,
    String? upiQrUrl,
    String? accountNumber,
    String? ifscCode,
    String? bankName,
    String? branchName,
    String? accountHolderName,
  }) async {
    final settingsMap = {
      'upi_id': upiId,
      'upi_name': upiName,
      'upi_qr_url': upiQrUrl ?? '',
      'account_number': accountNumber ?? '',
      'ifsc_code': ifscCode ?? '',
      'bank_name': bankName ?? '',
      'branch_name': branchName ?? '',
      'account_holder_name': accountHolderName ?? '',
    };

    // 1. Immediately persist locally in SharedPreferences so settings never reset
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('thali_provider_payment_settings_$providerId', jsonEncode(settingsMap));
    } catch (_) {}

    // 2. Synchronize to server API
    try {
      final uri = Uri.parse('$baseUrl/api/provider/payment-settings');
      await http.post(
        uri,
        headers: _authHeaders(json: true),
        body: jsonEncode({
          'provider_id': providerId,
          ...settingsMap,
        }),
      ).timeout(const Duration(seconds: 12));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> lookupUpi(String upiId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/upi/lookup?upi_id=${Uri.encodeComponent(upiId.trim())}');
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) return data;
      }
    } catch (_) {}
    return {};
  }

  static Future<Map<String, dynamic>> lookupIfsc(String ifsc) async {
    try {
      final uri = Uri.parse('$baseUrl/api/bank/ifsc?code=${Uri.encodeComponent(ifsc.trim().toUpperCase())}');
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) return data;
      }
    } catch (_) {}
    return {};
  }

  static Future<List<Map<String, dynamic>>> fetchChatMessages({
    required String providerId,
    required String customerId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat/messages?provider_id=$providerId&customer_id=$customerId');
      final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['messages'] as List<dynamic>? ?? []).map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> sendChatMessage({
    required String providerId,
    required String customerId,
    required String message,
    required String senderRole,
    required String senderName,
    required String senderId,
    String? attachmentUrl,
  }) async {
    final uri = Uri.parse('$baseUrl/api/chat/messages');
    final response = await http.post(
      uri,
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'provider_id': providerId,
        'customer_id': customerId,
        'message': message,
        'sender_role': senderRole,
        'sender_name': senderName,
        'sender_id': senderId,
        'attachment_url': attachmentUrl,
      }),
    ).timeout(const Duration(seconds: 10));
    final data = _decodeResponse(response);
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to send message');
    }
    return data['message'] as Map<String, dynamic>? ?? {};
  }

  static Future<List<Map<String, dynamic>>> fetchChatConversations(String providerId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat/conversations?provider_id=$providerId');
      final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['conversations'] as List<dynamic>? ?? []).map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> fetchNotifications(String providerId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/provider/notifications?provider_id=$providerId');
      final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'notifications': [], 'unread_count': 0};
  }

  static Future<void> markNotificationsRead(String providerId, {String? notificationId}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/provider/notifications');
      await http.post(
        uri,
        headers: _authHeaders(json: true),
        body: jsonEncode({
          'provider_id': providerId,
          if (notificationId != null) 'notification_id': notificationId,
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> fetchSubscribers(String providerId) async {
    final uri = Uri.parse('$baseUrl/api/provider/subscriptions?provider_id=$providerId');
    final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 12));
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
    final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 12));
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
      final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
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
          headers: _authHeaders(json: true),
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
          headers: _authHeaders(json: true),
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
      final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
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
      final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
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
    String dayOfWeek = 'Daily',
    String itemKind = '',
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/menu');
    final resolvedKind = itemKind.isNotEmpty ? itemKind : (isExtra ? 'addon' : 'included');
    final headers = {
      'Content-Type': 'application/json',
      if (currentSession?.token.isNotEmpty == true) 'Authorization': 'Bearer ${currentSession!.token}',
    };
    var response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'provider_id': providerId,
        'action': 'add_item',
        'name': name,
        'item_name': name,
        'slot': slot.toLowerCase(),
        'price': price,
        'is_extra': isExtra || resolvedKind == 'addon',
        'day_of_week': dayOfWeek,
        'item_kind': resolvedKind,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401 && currentSession != null && currentSession!.refreshToken.isNotEmpty) {
      try {
        final refreshed = await refreshSession(currentSession!.refreshToken);
        headers['Authorization'] = 'Bearer ${refreshed.token}';
        response = await http.post(
          uri,
          headers: headers,
          body: jsonEncode({
            'provider_id': providerId,
            'action': 'add_item',
            'name': name,
            'item_name': name,
            'slot': slot.toLowerCase(),
            'price': price,
            'is_extra': isExtra || resolvedKind == 'addon',
            'day_of_week': dayOfWeek,
            'item_kind': resolvedKind,
          }),
        ).timeout(const Duration(seconds: 10));
      } catch (_) {}
    }

    final data = jsonDecode(response.body);
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to add menu item');
    }

    // Direct atomic write to Supabase REST table for 100% customer coordination
    try {
      const supabaseUrl = 'https://mrbtwsrknqofjkrbssww.supabase.co';
      const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yYnR3c3JrbnFvZmprcmJzc3d3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5MzEzNDcsImV4cCI6MjEwODUwNzM0N30.TzKjZ593n_ku_81ZCAuzOkeHl-7pGmQjylzIP3cHssc';
      await http.post(
        Uri.parse('$supabaseUrl/rest/v1/menu_items'),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({
          'provider_id': providerId,
          'name': name,
          'description': '${slot.toLowerCase()} ${isExtra ? "add-on" : "item"}',
          'dietary_type': 'vegetarian',
          'price_paise': price * 100,
          'is_add_on': isExtra,
          'active': true,
        }),
      ).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  static Future<void> removeMenuItem({
    required String providerId,
    required String name,
    required String slot,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/menu');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (currentSession?.token.isNotEmpty == true) 'Authorization': 'Bearer ${currentSession!.token}',
      },
      body: jsonEncode({
        'provider_id': providerId,
        'action': 'remove_item',
        'name': name,
        'item_name': name,
        'slot': slot.toLowerCase(),
      }),
    ).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to remove menu item');
    }

    try {
      const supabaseUrl = 'https://mrbtwsrknqofjkrbssww.supabase.co';
      const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yYnR3c3JrbnFvZmprcmJzc3d3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5MzEzNDcsImV4cCI6MjEwODUwNzM0N30.TzKjZ593n_ku_81ZCAuzOkeHl-7pGmQjylzIP3cHssc';
      await http.delete(
        Uri.parse('$supabaseUrl/rest/v1/menu_items?provider_id=eq.$providerId&name=ilike.${Uri.encodeComponent(name)}'),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
        },
      ).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  static Future<void> toggleMenuAvailability({
    required String providerId,
    required String name,
    required bool isAvailable,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/menu');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (currentSession?.token.isNotEmpty == true) 'Authorization': 'Bearer ${currentSession!.token}',
      },
      body: jsonEncode({
        'provider_id': providerId,
        'action': 'toggle_availability',
        'name': name,
        'item_name': name,
        'is_available': isAvailable,
      }),
    ).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to toggle availability');
    }
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
      headers: {
        'Content-Type': 'application/json',
        if (currentSession?.token.isNotEmpty == true) 'Authorization': 'Bearer ${currentSession!.token}',
      },
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

    try {
      const supabaseUrl = 'https://mrbtwsrknqofjkrbssww.supabase.co';
      const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yYnR3c3JrbnFvZmprcmJzc3d3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5MzEzNDcsImV4cCI6MjEwODUwNzM0N30.TzKjZ593n_ku_81ZCAuzOkeHl-7pGmQjylzIP3cHssc';
      final isFixed = planType == 'fixed_period';
      final durMonths = isFixed ? (durationDays >= 30 ? (durationDays ~/ 30) : 1) : null;
      await http.post(
        Uri.parse('$supabaseUrl/rest/v1/subscription_plans'),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({
          'provider_id': providerId,
          'name': name,
          'description': description,
          'plan_type': planType,
          'duration_months': durMonths,
          'meal_credits': !isFixed ? (mealCredits ?? 60) : null,
          'price_paise': priceInr * 100,
          'currency': 'INR',
          'active': true,
          'published': true,
        }),
      ).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  static Future<void> deletePlan({
    required String providerId,
    required String planId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/plan?provider_id=$providerId&plan_id=$planId');
    final response = await http.delete(
      uri,
      headers: {
        if (currentSession?.token.isNotEmpty == true) 'Authorization': 'Bearer ${currentSession!.token}',
      },
    ).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to delete plan');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchOrders(String providerId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/provider/orders?provider_id=$providerId');
      final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
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
      headers: _authHeaders(json: true),
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
      final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
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
    bool? supportsDelivery,
    bool? supportsPickup,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/timings');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _authHeaders(json: true),
            body: jsonEncode({
              'provider_id': providerId,
              if (supportsDelivery != null) 'supports_delivery': supportsDelivery,
              if (supportsPickup != null) 'supports_pickup': supportsPickup,
              ...timings,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw Exception(friendlyError(e, action: 'save meal timings'));
    }

    final data = _decodeResponse(response, action: 'save meal timings');
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? friendlyError('HTTP ${response.statusCode}', statusCode: response.statusCode, action: 'save meal timings'));
    }
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
      headers: _authHeaders(json: true),
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

  static bool? staticKitchenStatus;

  static Future<bool> fetchKitchenStatus(String providerId) async {
    // 1. Static in-memory priority (locked in session)
    if (staticKitchenStatus != null) return staticKitchenStatus!;

    // 2. Persistent SharedPreferences manual choice priority
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('thali_kitchen_manual_status_$providerId')) {
        final val = prefs.getBool('thali_kitchen_manual_status_$providerId')!;
        staticKitchenStatus = val;
        return val;
      }
      if (prefs.containsKey('thali_kitchen_open_$providerId')) {
        final val = prefs.getBool('thali_kitchen_open_$providerId')!;
        staticKitchenStatus = val;
        return val;
      }
    } catch (_) {}

    // 3. Query server only if never manually chosen
    try {
      final uri = Uri.parse('$baseUrl/api/provider/status?provider_id=$providerId');
      final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isOpen = (data['is_open_today'] as bool?) ?? true;
        staticKitchenStatus = isOpen;
        return isOpen;
      }
    } catch (_) {}

    staticKitchenStatus = true;
    return true;
  }

  static Future<bool> toggleKitchenStatus({
    required String providerId,
    required bool isOpen,
  }) async {
    // 1. Immediately lock statically in memory
    staticKitchenStatus = isOpen;

    // 2. Persist locally in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('thali_kitchen_manual_status_$providerId', isOpen);
      await prefs.setBool('thali_kitchen_open_$providerId', isOpen);
    } catch (_) {}

    // 3. Background server synchronization (never block or throw)
    try {
      final uri = Uri.parse('$baseUrl/api/provider/status');
      final headers = {
        'Content-Type': 'application/json',
        if (currentSession?.token.isNotEmpty == true) 'Authorization': 'Bearer ${currentSession!.token}',
      };
      await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'provider_id': providerId,
          'is_open': isOpen,
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    return true;
  }

  static Future<Map<String, dynamic>> fetchSettlements(String providerId) async {
    Map<String, dynamic> localData = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('thali_settlements_$providerId');
      if (raw != null && raw.isNotEmpty) {
        localData = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}

    try {
      final uri = Uri.parse('$baseUrl/api/provider/settlements?provider_id=$providerId');
      final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('thali_settlements_$providerId', jsonEncode(data));
          } catch (_) {}
          return data;
        }
      }
    } catch (_) {}

    return localData.isNotEmpty ? localData : {
      'summary': {
        'total_collected_inr': 0,
        'upi_collected_inr': 0,
        'cash_collected_inr': 0,
        'active_subscribers': 0,
        'total_transactions': 0,
      },
      'paid': <Map<String, dynamic>>[],
      'history': <Map<String, dynamic>>[],
      'monthly_summary': <Map<String, dynamic>>[],
    };
  }

  static Future<Map<String, dynamic>> sendOtp({
    required String identifier,
    String purpose = 'signin',
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/otp/send');
    final response = await http.post(
      uri,
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'identifier': identifier.trim(),
        'purpose': purpose,
      }),
    ).timeout(const Duration(seconds: 12));
    final data = _decodeResponse(response);
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return data;
    }
    throw Exception(data['error'] ?? 'Could not send OTP.');
  }

  static Future<ProviderSession> verifyOtpSignIn({
    required String identifier,
    required String otp,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/otp/verify');
    final response = await http.post(
      uri,
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'identifier': identifier.trim(),
        'otp': otp.trim(),
        'create_session': true,
        'role': 'provider',
      }),
    ).timeout(const Duration(seconds: 12));
    final data = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
      throw Exception(data['error'] ?? 'Invalid or expired OTP.');
    }
    final user = data['user'] as Map<String, dynamic>? ?? {};
    final prov = data['provider'] as Map<String, dynamic>?;
    final providerId = (prov?['id'] ?? user['provider_id'] ?? '').toString().trim();
    if (providerId.isEmpty) {
      throw Exception('No registered kitchen is linked to this email or mobile. Please register your kitchen.');
    }
    final session = ProviderSession(
      token: data['token']?.toString() ?? '',
      userId: user['id']?.toString() ?? '',
      email: user['email']?.toString() ?? identifier.trim(),
      providerId: providerId,
      businessName: (prov?['display_name'] ?? user['provider_name'] ?? 'Kitchen Partner').toString(),
      locality: prov?['locality']?.toString() ?? '',
      city: prov?['city']?.toString() ?? '',
    );
    await saveSession(session);
    return session;
  }

  static Future<KitchenQueueResponse> fetchKitchenQueue({
    required String providerId,
    String? date,
    String slot = 'LUNCH',
  }) async {
    final dQuery = (date != null && date.isNotEmpty) ? '&date=$date' : '';
    final uri = Uri.parse('$baseUrl/api/provider/kitchen-queue?provider_id=$providerId&slot=${slot.toUpperCase()}$dQuery');
    http.Response response;
    try {
      response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 12));
    } catch (e) {
      throw Exception(friendlyError(e, action: 'load live kitchen queue'));
    }
    final data = _decodeResponse(response, action: 'load live kitchen queue');
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? friendlyError('HTTP ${response.statusCode}', statusCode: response.statusCode, action: 'load live kitchen queue'));
    }
    return KitchenQueueResponse.fromJson(data);
  }

  static Future<void> updateKitchenQueueStatus({
    required String providerId,
    required String subscriptionId,
    required String customerId,
    required String serviceDate,
    required String slot,
    required String status,
    int? etaMinutes,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/kitchen-queue');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _authHeaders(json: true),
            body: jsonEncode({
              'provider_id': providerId,
              'subscription_id': subscriptionId,
              'customer_id': customerId,
              'service_date': serviceDate,
              'slot': slot.toUpperCase(),
              'status': status,
              if (etaMinutes != null) 'eta_minutes': etaMinutes,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw Exception(friendlyError(e, action: 'update meal status'));
    }
    final data = _decodeResponse(response, action: 'update meal status');
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to update meal status.');
    }
  }

  static Future<Map<String, dynamic>> fetchReviews(String providerId) async {
    final uri = Uri.parse('$baseUrl/api/mess/reviews?provider_id=$providerId');
    http.Response response;
    try {
      response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception(friendlyError(e, action: 'load customer reviews'));
    }
    final data = _decodeResponse(response, action: 'load customer reviews');
    if (response.statusCode >= 400 || data['success'] == false) {
      final rawErr = data['error']?.toString() ?? '';
      if (rawErr.toLowerCase().contains('persisted provider review table')) {
        throw Exception('Reviews database table is missing or backend update is not deployed yet.');
      }
      throw Exception(rawErr.isNotEmpty ? rawErr : 'Failed to load reviews.');
    }
    return data;
  }

  static Future<void> replyToReview({
    required String providerId,
    required String reviewId,
    required String reply,
  }) async {
    final uri = Uri.parse('$baseUrl/api/mess/reviews');
    http.Response response;
    try {
      response = await http
          .patch(
            uri,
            headers: _authHeaders(json: true),
            body: jsonEncode({
              'provider_id': providerId,
              'review_id': reviewId,
              'partner_reply': reply,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw Exception(friendlyError(e, action: 'post reply'));
    }
    final data = _decodeResponse(response, action: 'post reply');
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to post reply.');
    }
  }

  static Future<Map<String, dynamic>> fetchProviderProfile(String providerId) async {
    final uri = Uri.parse('$baseUrl/api/provider/profile?provider_id=$providerId');
    http.Response response;
    try {
      response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception(friendlyError(e, action: 'load kitchen settings'));
    }
    final data = _decodeResponse(response, action: 'load kitchen settings');
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to load kitchen settings.');
    }
    return data['provider'] as Map<String, dynamic>? ?? {};
  }

  static Future<Map<String, dynamic>> updateProviderProfile({
    required String providerId,
    bool? supportsDelivery,
    bool? supportsPickup,
    bool? allowsTakeaway,
    String? description,
    String? coverImageBase64,
  }) async {
    final uri = Uri.parse('$baseUrl/api/provider/profile');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _authHeaders(json: true),
            body: jsonEncode({
              'provider_id': providerId,
              if (supportsDelivery != null) 'supports_delivery': supportsDelivery,
              if (supportsPickup != null) 'supports_pickup': supportsPickup,
              if (allowsTakeaway != null) 'allows_takeaway': allowsTakeaway,
              if (description != null) 'description': description,
              if (coverImageBase64 != null) 'cover_image_base64': coverImageBase64,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw Exception(friendlyError(e, action: 'update kitchen settings'));
    }
    final data = _decodeResponse(response, action: 'update kitchen settings');
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(data['error'] ?? 'Failed to update kitchen settings.');
    }
    return data;
  }
}
