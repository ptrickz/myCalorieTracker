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
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not load profile"));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile(String token) async {
    final response = await http.get(
      Uri.parse("$apiBaseUrl/profile"),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not load profile"));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(
    String token, {
    required String dateOfBirth,
    required String sex,
    required double heightCm,
    required String activityLevel,
    required String goalType,
    required double weightKg,
  }) async {
    final response = await http.patch(
      Uri.parse("$apiBaseUrl/profile"),
      headers: _authHeaders(token, withJson: true),
      body: jsonEncode({
        "dateOfBirth": dateOfBirth,
        "sex": sex,
        "heightCm": heightCm,
        "activityLevel": activityLevel,
        "goalType": goalType,
        "weightKg": weightKg,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not save profile"));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> searchFoods(String token, String query) async {
    final response = await http.get(
      Uri.parse("$apiBaseUrl/foods?search=${Uri.encodeQueryComponent(query)}"),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not search foods"));
    }

    return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createFood(
    String token, {
    required String name,
    required double caloriesPer100g,
    required double proteinPer100g,
    required double carbsPer100g,
    required double fatPer100g,
  }) async {
    final response = await http.post(
      Uri.parse("$apiBaseUrl/foods"),
      headers: _authHeaders(token, withJson: true),
      body: jsonEncode({
        "name": name,
        "caloriesPer100g": caloriesPer100g,
        "proteinPer100g": proteinPer100g,
        "carbsPer100g": carbsPer100g,
        "fatPer100g": fatPer100g,
      }),
    );

    if (response.statusCode != 201) {
      throw ApiException(_extractError(response, "Could not create food"));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> createLogEntry(
    String token, {
    required String foodItemId,
    required double servingGrams,
    required String mealType,
  }) async {
    final response = await http.post(
      Uri.parse("$apiBaseUrl/logs"),
      headers: _authHeaders(token, withJson: true),
      body: jsonEncode({
        "foodItemId": foodItemId,
        "servingGrams": servingGrams,
        "mealType": mealType,
      }),
    );

    if (response.statusCode != 201) {
      throw ApiException(_extractError(response, "Could not log this food"));
    }
  }

  Future<Map<String, dynamic>> getTodaysLogs(String token) async {
    final response = await http.get(
      Uri.parse("$apiBaseUrl/logs"),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not load today's log"));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, String> _authHeaders(String token, {bool withJson = false}) {
    return {
      "Authorization": "Bearer $token",
      if (withJson) "Content-Type": "application/json",
    };
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
