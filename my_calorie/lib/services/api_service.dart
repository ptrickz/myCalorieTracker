import "dart:convert";
import "package:http/http.dart" as http;
import "../config.dart";

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  Future<void> signup(String email, String password) async {
    final response = await http.post(
      Uri.parse("$apiBaseUrl/auth/signup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode != 201) {
      throw ApiException(_extractError(response, "Signup failed"));
    }
  }

  Future<String> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$apiBaseUrl/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Login failed"));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data["token"] as String;
  }

  Future<Map<String, dynamic>> getMe(String token) async {
    final response = await http.get(
      Uri.parse("$apiBaseUrl/me"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not load profile"));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _extractError(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data["error"] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
