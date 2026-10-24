import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> _request(String method, String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _headers();

    late http.Response response;

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;

      case 'PUT':
        response = await http.put(uri, headers: headers);
        break;

      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;

      default:
        throw Exception('Unsupported request method: $method');
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      throw Exception(
        'Invalid JSON response (HTTP ${response.statusCode}): $e',
      );
    }

    final Map<String, dynamic> data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ?? 'Request failed (${response.statusCode}).',
    );
  }

  // Get all notifications.
  Future<List<NotificationModel>> getNotifications() async {
    final data = await _request('GET', '/api/notifications');
    final items = data['notifications'];

    if (items is! List) {
      throw Exception('Invalid notifications response.');
    }

    return items.map((item) {
      return NotificationModel.fromJson(Map<String, dynamic>.from(item as Map));
    }).toList();
  }

  // Get unread notification count.
  Future<int> getUnreadCount() async {
    final data = await _request('GET', '/api/notifications/unread-count');

    return int.tryParse(data['unread_count']?.toString() ?? '0') ?? 0;
  }

  // Mark one notification as read.
  Future<void> markAsRead(int notificationId) async {
    await _request('PUT', '/api/notifications/$notificationId/read');
  }

  // Mark all notifications as read.
  Future<void> markAllAsRead() async {
    await _request('PUT', '/api/notifications/read-all');
  }

  // Delete one notification.
  Future<void> deleteNotification(int notificationId) async {
    await _request('DELETE', '/api/notifications/$notificationId');
  }
}
