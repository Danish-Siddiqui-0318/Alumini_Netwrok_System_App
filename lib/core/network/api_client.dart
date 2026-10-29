import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';

class ApiClient {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // POST JSON

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    // Login and signup must work without an existing token.
    final isPublicAuthEndpoint =
        endpoint == ApiConfig.login || endpoint == ApiConfig.register;

    String? token;

    if (!isPublicAuthEndpoint) {
      token = await _getToken();
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body ?? {}),
    );

    return _handleResponse(response);
  }

  // GET JSON with authentication
  Future<Map<String, dynamic>> get(String endpoint) async {
    final token = await _getToken();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return _handleResponse(response);
  }

  // PUT JSON with authentication
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _getToken();

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body ?? {}),
    );

    return _handleResponse(response);
  }

  // Upload a file using multipart/form-data with authentication
  Future<Map<String, dynamic>> multipartPost(
    String endpoint, {
    required File file,
    required String fieldName,
  }) async {
    final token = await _getToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    final extension = file.path.split('.').last.toLowerCase();

    final subtype = switch (extension) {
      'png' => 'png',
      'webp' => 'webp',
      'gif' => 'gif',
      'jpg' || 'jpeg' => 'jpeg',
      _ => 'jpeg',
    };

    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        contentType: MediaType('image', subtype),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return _handleResponse(response);
  }

  // Read authentication token
  Future<String> _getToken() async {
    final token = await _storage.read(key: 'auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    return token;
  }

  // Handle server responses

  Map<String, dynamic> _handleResponse(http.Response response) {
    debugPrint('========== API RESPONSE ==========');
    debugPrint('URL: ${response.request?.url}');
    debugPrint('STATUS: ${response.statusCode}');
    debugPrint('CONTENT-TYPE: ${response.headers['content-type']}');
    debugPrint('BODY: ${response.body}');
    debugPrint('==================================');

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Non-JSON server response. HTTP ${response.statusCode}. '
        'Check the Debug Console for the BODY.',
      );
    }

    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ?? 'Request failed (${response.statusCode}).',
    );
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    final token = await _getToken();

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return _handleResponse(response);
  }
}
