import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';

class PostRepository {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String> _getToken() async {
    final token = await _storage.read(key: 'auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    return token;
  }

  Map<String, String> _headers(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw Exception('Unexpected response from server.');
  }

  // GET /posts
  Future<List<PostModel>> getPosts() async {
    final token = await _getToken();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.posts}'),
      headers: _headers(token),
    );

    final data = _decodeResponse(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load posts.');
    }

    final List<dynamic> posts = data['posts'] ?? [];

    return posts
        .map((post) => PostModel.fromJson(Map<String, dynamic>.from(post)))
        .toList();
  }

  // POST /posts
  // Supports text-only posts and posts with an image.
  Future<void> createPost({required String content, File? image}) async {
    final token = await _getToken();

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.posts}');

    late http.Response response;

    if (image != null) {
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = content;

      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final streamedResponse = await request.send();

      response = await http.Response.fromStream(streamedResponse);
    } else {
      response = await http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({'content': content}),
      );
    }

    final data = _decodeResponse(response.body);

    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to create post.');
    }
  }

  // GET /api/posts/:postId/like
  // Returns whether the current user has liked this post.
  Future<bool> getLikeStatus(int postId) async {
    final token = await _getToken();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.likes}/$postId/like'),
      headers: _headers(token),
    );

    final data = _decodeResponse(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Could not load like status.');
    }

    return data['liked'] == true || data['liked'].toString() == '1';
  }

  // POST or DELETE /api/posts/:postId/like
  Future<Map<String, dynamic>> toggleLike({
    required int postId,
    required bool currentlyLiked,
  }) async {
    final token = await _getToken();

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.likes}/$postId/like',
    );

    final response = currentlyLiked
        ? await http.delete(uri, headers: _headers(token))
        : await http.post(uri, headers: _headers(token));

    final data = _decodeResponse(response.body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to update like.');
    }

    return data;
  }

  Future<void> deletePost(int postId) async {
    final token = await _getToken();

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.posts}/$postId'),
      headers: _headers(token),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final data = _decodeResponse(response.body);
      throw Exception(data['message'] ?? 'Failed to delete post.');
    }
  }

  Future<void> updatePost({
    required int postId,
    required String content,
    File? image,
  }) async {
    final token = await _getToken();

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.posts}/$postId');

    final request = http.MultipartRequest('PUT', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['content'] = content;

    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      final data = _decodeResponse(response.body);
      throw Exception(data['message'] ?? 'Failed to update post.');
    }
  }

  // GET /api/posts/:postId/comments
  Future<List<CommentModel>> getComments(int postId) async {
    final token = await _getToken();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/comments'),
      headers: _headers(token),
    );

    final data = _decodeResponse(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load comments.');
    }

    final List<dynamic> comments = data['comments'] ?? [];

    return comments
        .map((item) => CommentModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // POST /api/posts/:postId/comments
  Future<void> createComment({
    required int postId,
    required String content,
  }) async {
    final token = await _getToken();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/comments'),
      headers: _headers(token),
      body: jsonEncode({'content': content.trim()}),
    );

    final data = _decodeResponse(response.body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to add comment.');
    }
  }

  // PUT /api/comments/:commentId
  Future<void> updateComment({
    required int commentId,
    required String content,
  }) async {
    final token = await _getToken();

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/comments/$commentId'),
      headers: _headers(token),
      body: jsonEncode({'content': content.trim()}),
    );

    final data = _decodeResponse(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to update comment.');
    }
  }

  // DELETE /api/comments/:commentId
  Future<void> deleteComment(int commentId) async {
    final token = await _getToken();

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/comments/$commentId'),
      headers: _headers(token),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final data = _decodeResponse(response.body);
      throw Exception(data['message'] ?? 'Failed to delete comment.');
    }
  }
}
