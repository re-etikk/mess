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
    defaultValue: 'https://mess-beta.vercel.app',
  );

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

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      final user = data['user'] as Map<String, dynamic>? ?? {};
      return CustomerAuthResult(
        userId: user['id']?.toString() ?? 'usr-cust',
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

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      final user = data['user'] as Map<String, dynamic>? ?? {};
      return CustomerAuthResult(
        userId: user['id']?.toString() ?? 'usr-cust',
        email: user['email']?.toString() ?? email.trim(),
        name: user['name']?.toString() ?? name.trim(),
        token: data['token']?.toString() ?? '',
      );
    }
    throw Exception(data['error'] ?? data['message'] ?? 'Registration failed.');
  }
}
