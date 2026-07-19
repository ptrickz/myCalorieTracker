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
    double? weightKg,
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
        "weightKg": ?weightKg,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not save profile"));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// With no query (or an empty one), returns the user's recent foods first,
  /// then fills up to 20 with other available foods — used as the Add Food
  /// screen's default list before the user types anything.
  Future<List<Map<String, dynamic>>> searchFoods(String token, [String? query]) async {
    final trimmed = query?.trim() ?? "";
    final uri = trimmed.isEmpty
        ? Uri.parse("$apiBaseUrl/foods")
        : Uri.parse("$apiBaseUrl/foods?search=${Uri.encodeQueryComponent(trimmed)}");

    final response = await http.get(uri, headers: _authHeaders(token));

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
    String? photoBase64,
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
        "photoBase64": ?photoBase64,
      }),
    );

    if (response.statusCode != 201) {
      throw ApiException(_extractError(response, "Could not create food"));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyFoods(String token) async {
    final response = await http.get(
      Uri.parse("$apiBaseUrl/foods/mine"),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not load your custom foods"));
    }

    return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> updateFood(
    String token,
    String foodId, {
    String? name,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    String? photoBase64,
  }) async {
    final response = await http.patch(
      Uri.parse("$apiBaseUrl/foods/$foodId"),
      headers: _authHeaders(token, withJson: true),
      body: jsonEncode({
        "name": ?name,
        "caloriesPer100g": ?caloriesPer100g,
        "proteinPer100g": ?proteinPer100g,
        "carbsPer100g": ?carbsPer100g,
        "fatPer100g": ?fatPer100g,
        "photoBase64": ?photoBase64,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not update this food"));
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

  Future<void> updateLogEntry(
    String token,
    String logEntryId, {
    double? servingGrams,
    String? mealType,
  }) async {
    final response = await http.patch(
      Uri.parse("$apiBaseUrl/logs/$logEntryId"),
      headers: _authHeaders(token, withJson: true),
      body: jsonEncode({
        "servingGrams": ?servingGrams,
        "mealType": ?mealType,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not update this entry"));
    }
  }

  Future<void> deleteLogEntry(String token, String logEntryId) async {
    final response = await http.delete(
      Uri.parse("$apiBaseUrl/logs/$logEntryId"),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 204) {
      throw ApiException(_extractError(response, "Could not delete this entry"));
    }
  }

  Future<Map<String, dynamic>> getLogs(String token, {String? date}) async {
    final uri = date == null
        ? Uri.parse("$apiBaseUrl/logs")
        : Uri.parse("$apiBaseUrl/logs?date=$date");
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not load log"));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStreak(String token) async {
    final response = await http.get(
      Uri.parse("$apiBaseUrl/logs/streak"),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not load streak"));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getWeightLogs(String token) async {
    final response = await http.get(
      Uri.parse("$apiBaseUrl/weight-logs"),
      headers: _authHeaders(token),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not load weight history"));
    }

    return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> visionLog(
    String token, {
    required String imageBase64,
    required String mediaType,
    required String mode,
  }) async {
    final response = await http.post(
      Uri.parse("$apiBaseUrl/vision-log"),
      headers: _authHeaders(token, withJson: true),
      body: jsonEncode({"image": imageBase64, "mediaType": mediaType, "mode": mode}),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not analyze this photo"));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> addWeightLog(String token, double weightKg) async {
    final response = await http.post(
      Uri.parse("$apiBaseUrl/weight-logs"),
      headers: _authHeaders(token, withJson: true),
      body: jsonEncode({"weightKg": weightKg}),
    );

    if (response.statusCode != 201) {
      throw ApiException(_extractError(response, "Could not log weight"));
    }
  }

  Future<void> updateGoals(
    String token, {
    double? goalWeightKg,
    double? milestoneWeightKg,
    double? proteinTargetG,
    bool? useCustomCalorieTargets,
    double? weekdayTargetCalories,
    double? weekendTargetCalories,
  }) async {
    final response = await http.patch(
      Uri.parse("$apiBaseUrl/profile"),
      headers: _authHeaders(token, withJson: true),
      body: jsonEncode({
        "goalWeightKg": ?goalWeightKg,
        "milestoneWeightKg": ?milestoneWeightKg,
        "proteinTargetG": ?proteinTargetG,
        "useCustomCalorieTargets": ?useCustomCalorieTargets,
        "weekdayTargetCalories": ?weekdayTargetCalories,
        "weekendTargetCalories": ?weekendTargetCalories,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response, "Could not save goals"));
    }
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
