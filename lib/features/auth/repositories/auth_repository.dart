import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthRepository(this._apiClient);

  Future<void> login({required String email, required String password}) async {
    final data = await _apiClient.post(
      ApiConfig.login,
      body: {'email': email.trim(), 'password': password},
    );

    final token = data['token'];

    if (token == null || token.toString().isEmpty) {
      throw Exception('The server did not return an authentication token.');
    }

    await _storage.write(key: 'auth_token', value: token.toString());
  }

  Future<void> signup({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    await _apiClient.post(
      ApiConfig.register,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
      },
    );
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  Future<String?> getSavedToken() {
    return _storage.read(key: 'auth_token');
  }

  Future<UserModel> getCurrentUser() async {
    final token = await getSavedToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load current user.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Supports either { user: {...} } or a direct user object.
    final userData = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;

    return UserModel.fromJson(userData);
  }


}
