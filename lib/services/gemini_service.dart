import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class NutritionResult {
  final String mealName;
  final int caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatsPer100g;
  final double fiberPer100g;
  final double sugarPer100g;
  final String suitableFor;
  final String description;
  final double confidence;
  final int grams;

  NutritionResult({
    required this.mealName,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatsPer100g,
    required this.fiberPer100g,
    this.sugarPer100g = 0,
    this.suitableFor = 'both',
    required this.description,
    this.confidence = 0.85,
    this.grams = 100,
  });

  int get calories => (caloriesPer100g * grams / 100).round();
  double get protein => proteinPer100g * grams / 100;
  double get carbs => carbsPer100g * grams / 100;
  double get fats => fatsPer100g * grams / 100;
  double get fiber => fiberPer100g * grams / 100;
  double get sugar => sugarPer100g * grams / 100;

  NutritionResult withGrams(int g) {
    return NutritionResult(
      mealName: mealName,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatsPer100g: fatsPer100g,
      fiberPer100g: fiberPer100g,
      sugarPer100g: sugarPer100g,
      suitableFor: suitableFor,
      description: description,
      confidence: confidence,
      grams: g,
    );
  }

  factory NutritionResult.fromJson(Map<String, dynamic> json) {
    return NutritionResult(
      mealName: json['meal_name'] as String? ?? 'Unknown',
      caloriesPer100g: (json['calories_per_100g'] as num?)?.toInt() ?? (json['calories'] as num?)?.toInt() ?? 0,
      proteinPer100g: (json['protein_g_per_100g'] as num?)?.toDouble() ?? (json['protein_g'] as num?)?.toDouble() ?? 0,
      carbsPer100g: (json['carbs_g_per_100g'] as num?)?.toDouble() ?? (json['carbs_g'] as num?)?.toDouble() ?? 0,
      fatsPer100g: (json['fats_g_per_100g'] as num?)?.toDouble() ?? (json['fats_g'] as num?)?.toDouble() ?? 0,
      fiberPer100g: (json['fiber_g_per_100g'] as num?)?.toDouble() ?? (json['fiber_g'] as num?)?.toDouble() ?? 0,
      sugarPer100g: (json['sugar_g_per_100g'] as num?)?.toDouble() ?? 0,
      suitableFor: json['suitable_for'] as String? ?? 'both',
      description: json['description'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.7,
    );
  }
}

class GeminiService {
  static String _serverUrl = 'https://macro-snap-backend-production.up.railway.app';

  static void setServerUrl(String url) {
    _serverUrl = url.trim();
  }

  static String get serverUrl => _serverUrl;
  static bool get hasServerUrl => _serverUrl.isNotEmpty;

  static Future<NutritionResult> analyzeFoodImage(String imagePath) async {
    if (!hasServerUrl) {
      throw Exception('Server URL not set. Enter your server URL in Settings.');
    }

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file not found at: $imagePath');
      }

      final request = http.MultipartRequest('POST', Uri.parse('$_serverUrl/analyze'));
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(body['error'] as String? ?? 'Server error (${response.statusCode})');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return NutritionResult.fromJson(json);
    } on SocketException {
      throw Exception('Cannot reach server at $serverUrl.\nMake sure your phone is on the same WiFi and the backend is running.');
    } on http.ClientException {
      throw Exception('Connection failed. Check that the server is running at $serverUrl.');
    } on FormatException {
      throw Exception('Invalid response from server.');
    }
  }
}
