import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class MessageRepository {
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

  Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _headers();

    late http.Response response;

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;

      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        );
        break;

      case 'PUT':
        response = await http.put(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
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
    } catch (_) {
      throw Exception('Invalid server response (${response.statusCode}).');
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

  // Load the current user's chat list.
  Future<List<ConversationModel>> getConversations() async {
    final data = await _request('GET', '/api/messages/conversations');

    final items = data['conversations'];

    if (items is! List) {
      throw Exception('Invalid conversations response.');
    }

    return items.map((item) {
      return ConversationModel.fromJson(Map<String, dynamic>.from(item as Map));
    }).toList();
  }

  // Load messages exchanged with another user.
  Future<List<MessageModel>> getMessages(int otherUserId) async {
    final data = await _request('GET', '/api/messages/$otherUserId');

    final items = data['messages'];

    if (items is! List) {
      throw Exception('Invalid messages response.');
    }

    return items.map((item) {
      return MessageModel.fromJson(Map<String, dynamic>.from(item as Map));
    }).toList();
  }

  // Send a message to another user.
  Future<int> sendMessage({
    required int receiverId,
    required String message,
  }) async {
    final data = await _request(
      'POST',
      '/api/messages',
      body: {'receiver_id': receiverId, 'message': message},
    );

    final messageId = int.tryParse(data['message_id']?.toString() ?? '');

    if (messageId == null) {
      throw Exception('The server did not return a message ID.');
    }

    return messageId;
  }

  // Mark a received message as read.
  Future<void> markAsRead(int messageId) async {
    await _request('PUT', '/api/messages/$messageId/read');
  }

  // Delete a message sent by the current user.
  Future<void> deleteMessage(int messageId) async {
    await _request('DELETE', '/api/messages/$messageId');
  }
}
