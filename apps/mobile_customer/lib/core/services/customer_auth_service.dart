import 'dart:convert';
import 'package:http/http.dart' as http;

class CustomerAuthResult {
  CustomerAuthResult({
    required this.userId,
    required this.email,
    required this.name,
    required this.token,
    this.phone = '',
    this.refreshToken = '',
    this.foodPreference = 'veg',
    this.locality = '',
    this.city = '',
    this.needsProfileSetup = false,
  });

  final String userId;
  final String email;
  final String name;
  final String phone;
  final String token;
  final String refreshToken;
  final String foodPreference;
  final String locality;
  final String city;
  final bool needsProfileSetup;
}

class CustomerAuthService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://www.thali.store',
  );

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw Exception('The sign-in service redirected the request. Update the app and try again.');
    }
    final trimmed = response.body.trimLeft().toLowerCase();
    if (response.statusCode == 404 || trimmed.startsWith('<!doctype') || trimmed.startsWith('<html')) {
      throw Exception('This sign-in feature is not live on thali.store yet. Please redeploy the web server.');
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // ignore
    }
    throw Exception('Server could not process sign-in (HTTP ${response.statusCode}). Please check your connection and retry.');
  }

  static Future<Map<String, dynamic>> sendOtp({
    required String identifier,
    String purpose = 'signin',
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/otp/send');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identifier': identifier.trim(),
            'purpose': purpose,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final data = _decodeResponse(response);
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return data;
    }
    throw Exception(data['error'] ?? 'Could not send verification code.');
  }

  static Future<CustomerAuthResult> verifyOtpSignIn({
    required String identifier,
    required String otp,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/otp/verify');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identifier': identifier.trim(),
            'otp': otp.trim(),
            'create_session': true,
            'role': 'customer',
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = _decodeResponse(response);
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      final user = data['user'] as Map<String, dynamic>? ?? {};
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      return CustomerAuthResult(
        userId: user['id']?.toString() ?? '',
        email: user['email']?.toString() ?? (identifier.contains('@') ? identifier.trim() : ''),
        phone: user['phone']?.toString() ?? (!identifier.contains('@') ? identifier.trim() : ''),
        name: user['name']?.toString() ?? profile['display_name']?.toString() ?? '',
        token: data['token']?.toString() ?? '',
        foodPreference: profile['food_preference']?.toString() ?? 'veg',
        locality: profile['default_locality']?.toString() ?? '',
        city: profile['default_city']?.toString() ?? '',
        needsProfileSetup: data['needs_profile_setup'] == true,
      );
    }
    throw Exception(data['error'] ?? 'Invalid or expired OTP code.');
  }

  static Future<CustomerAuthResult> login({
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
            'role': 'customer',
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = _decodeResponse(response);
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      final user = data['user'] as Map<String, dynamic>? ?? {};
      return CustomerAuthResult(
        userId: user['id']?.toString() ?? '',
        email: user['email']?.toString() ?? email.trim(),
        phone: user['phone']?.toString() ?? '',
        name: user['name']?.toString() ?? '',
        token: data['token']?.toString() ?? '',
        refreshToken: data['refresh_token']?.toString() ?? '',
        needsProfileSetup: (user['name']?.toString().trim().isEmpty ?? true),
      );
    }
    throw Exception(data['error'] ?? data['message'] ?? 'Login failed. Please check credentials.');
  }

  static Future<CustomerAuthResult> refreshSession({
    required String refreshToken,
    required String fallbackUserId,
    required String fallbackEmail,
    required String fallbackName,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(const Duration(seconds: 12));
    final data = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
      throw Exception(data['error'] ?? 'Your session could not be refreshed.');
    }
    final user = data['user'] as Map<String, dynamic>? ?? {};
    return CustomerAuthResult(
      userId: user['id']?.toString() ?? fallbackUserId,
      email: user['email']?.toString() ?? fallbackEmail,
      name: user['name']?.toString() ?? fallbackName,
      token: data['token']?.toString() ?? '',
      refreshToken: data['refresh_token']?.toString() ?? refreshToken,
    );
  }

  static Future<CustomerAuthResult> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/register');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name.trim(),
            'email': email.trim(),
            'password': password,
            'phone': phone?.trim() ?? '',
            'role': 'customer',
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = _decodeResponse(response);
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      final user = data['user'] as Map<String, dynamic>? ?? {};
      return CustomerAuthResult(
        userId: user['id']?.toString() ?? '',
        email: user['email']?.toString() ?? email.trim(),
        phone: user['phone']?.toString() ?? (phone?.trim() ?? ''),
        name: user['name']?.toString() ?? name.trim(),
        token: data['token']?.toString() ?? '',
        refreshToken: data['refresh_token']?.toString() ?? '',
        needsProfileSetup: true,
      );
    }
    throw Exception(data['error'] ?? data['message'] ?? 'Registration failed.');
  }
}
