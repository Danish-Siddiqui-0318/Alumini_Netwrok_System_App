import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/post_model.dart';
import '../repositories/post_repository.dart';
import '../models/comment_model.dart';

class PostProvider extends ChangeNotifier {
  final PostRepository _repository = PostRepository();

  List<PostModel> _posts = [];
  final Map<int, bool> _likedPosts = {};

  final Map<int, List<CommentModel>> _commentsByPost = {};
  final Map<int, bool> _loadingComments = {};

  List<CommentModel> commentsForPost(int postId) =>
      _commentsByPost[postId] ?? [];

  bool areCommentsLoading(int postId) => _loadingComments[postId] ?? false;

  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;

  List<PostModel> get posts => _posts;

  Map<int, bool> get likedPosts => _likedPosts;

  bool get isLoading => _isLoading;

  bool get isCreating => _isCreating;

  String? get errorMessage => _errorMessage;

  Future<void> loadPosts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _posts = await _repository.getPosts();

      // Fetch whether the current user liked each post.
      await Future.wait(
        _posts.map((post) async {
          try {
            _likedPosts[post.postId] = await _repository.getLikeStatus(
              post.postId,
            );
          } catch (_) {
            _likedPosts.putIfAbsent(post.postId, () => false);
          }
        }),
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createPost({required String content, File? image}) async {
    if (content.trim().isEmpty && image == null) {
      _errorMessage = 'Write something or select an image.';
      notifyListeners();
      return false;
    }

    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.createPost(content: content.trim(), image: image);

      await loadPosts();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(PostModel post) async {
    final wasLiked = _likedPosts[post.postId] ?? false;

    // Update immediately for a responsive feed.
    _likedPosts[post.postId] = !wasLiked;

    final index = _posts.indexWhere((p) => p.postId == post.postId);

    if (index != -1) {
      final oldPost = _posts[index];
      _posts[index] = oldPost.copyWith(
        likeCount: (oldPost.likeCount + (wasLiked ? -1 : 1)).clamp(0, 999999),
      );
    }

    notifyListeners();

    try {
      final result = await _repository.toggleLike(
        postId: post.postId,
        currentlyLiked: wasLiked,
      );

      final serverCount = int.tryParse(result['like_count']?.toString() ?? '');

      if (index != -1 && serverCount != null) {
        _posts[index] = _posts[index].copyWith(likeCount: serverCount);
      }
    } catch (e) {
      // Restore the previous state if the request fails.
      _likedPosts[post.postId] = wasLiked;

      if (index != -1) {
        final oldPost = _posts[index];
        _posts[index] = oldPost.copyWith(
          likeCount: oldPost.likeCount + (wasLiked ? 1 : -1),
        );
      }

      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  Future<bool> deletePost(int postId) async {
    try {
      _errorMessage = null;

      await _repository.deletePost(postId);

      _posts.removeWhere((post) => post.postId == postId);
      _likedPosts.remove(postId);

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePost({
    required int postId,
    required String content,
    File? image,
  }) async {
    try {
      _errorMessage = null;

      await _repository.updatePost(
        postId: postId,
        content: content,
        image: image,
      );

      await loadPosts();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadComments(int postId) async {
    _loadingComments[postId] = true;
    notifyListeners();

    try {
      _commentsByPost[postId] = await _repository.getComments(postId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _loadingComments[postId] = false;
      notifyListeners();
    }
  }

  Future<bool> addComment({
    required int postId,
    required String content,
  }) async {
    if (content.trim().isEmpty) return false;

    try {
      _errorMessage = null;

      await _repository.createComment(postId: postId, content: content);

      await loadComments(postId);
      _updateCommentCount(postId, 1);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> editComment({
    required int postId,
    required int commentId,
    required String content,
  }) async {
    if (content.trim().isEmpty) return false;

    try {
      _errorMessage = null;

      await _repository.updateComment(commentId: commentId, content: content);

      await loadComments(postId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeComment({
    required int postId,
    required int commentId,
  }) async {
    try {
      await _repository.deleteComment(commentId);

      _commentsByPost[postId]?.removeWhere(
        (comment) => comment.commentId == commentId,
      );

      _updateCommentCount(postId, -1);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _updateCommentCount(int postId, int change) {
    final index = _posts.indexWhere((post) => post.postId == postId);

    if (index == -1) return;

    final oldPost = _posts[index];

    _posts[index] = oldPost.copyWith(
      commentCount: (oldPost.commentCount + change).clamp(0, 999999),
    );

    notifyListeners();
  }
}
