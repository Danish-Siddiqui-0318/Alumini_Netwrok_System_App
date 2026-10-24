
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiClient {
  Future<Map<String, dynamic>> post(
      String endpoint, {
        Map<String, dynamic>? body,
      }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body ?? {}),
    );

    final dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from server.');
    }

    final Map<String, dynamic> data =
    decoded is Map<String, dynamic> ? decoded : {};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(
      data['message'] ?? 'Request failed (${response.statusCode}).',
    );
  }
}
