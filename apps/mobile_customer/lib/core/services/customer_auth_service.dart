import 'dart:convert';
import 'package:http/http.dart' as http;

class CustomerAuthResult {
  CustomerAuthResult({
    required this.userId,
    required this.email,
    required this.name,
    required this.token,
  });

  final String userId;
  final String email;
  final String name;
  final String token;
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
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Translate proxy, deployment, and HTML responses into a useful app error.
    }
    throw Exception('The server returned an unexpected response. Please try again shortly.');
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
        userId: user['id']?.toString() ?? (throw Exception('Authentication response is missing the account ID.')),
        email: user['email']?.toString() ?? email.trim(),
        name: user['name']?.toString() ?? email.split('@')[0],
        token: data['token']?.toString() ?? '',
      );
    }
    throw Exception(data['error'] ?? data['message'] ?? 'Login failed. Please check credentials.');
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
        userId: user['id']?.toString() ?? (throw Exception('Registration response is missing the account ID.')),
        email: user['email']?.toString() ?? email.trim(),
        name: user['name']?.toString() ?? name.trim(),
        token: data['token']?.toString() ?? '',
      );
    }
    throw Exception(data['error'] ?? data['message'] ?? 'Registration failed.');
  }

  static Future<void> deleteAccount({required String token}) async {
    if (token.isEmpty) throw Exception('Your login session expired. Sign in again before deleting your account.');
    final response = await http.delete(
      Uri.parse('$baseUrl/api/account/deletion'),
      headers: {'Authorization': 'Bearer $token', 'x-account-deletion-confirmation': 'DELETE'},
    ).timeout(const Duration(seconds: 20));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
      throw Exception(data['error'] ?? 'Account deletion could not be completed.');
    }
  }
}
