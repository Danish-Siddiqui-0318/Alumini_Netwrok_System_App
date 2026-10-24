import 'package:flutter/foundation.dart';

import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../repositories/message_repository.dart';

class MessageProvider extends ChangeNotifier {
  final MessageRepository _repository = MessageRepository();

  List<ConversationModel> _conversations = [];
  List<MessageModel> _messages = [];

  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  bool _isSending = false;

  String? _errorMessage;
  int? _currentUserId;
  int? _activeConversationUserId;

  List<ConversationModel> get conversations => _conversations;

  List<MessageModel> get messages => _messages;

  bool get isLoadingConversations => _isLoadingConversations;

  bool get isLoadingMessages => _isLoadingMessages;

  bool get isSending => _isSending;

  String? get errorMessage => _errorMessage;

  int get totalUnreadMessages {
    return _conversations.fold(
      0,
      (total, conversation) => total + conversation.unreadCount,
    );
  }

  // Load the chat list.
  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _conversations = await _repository.getConversations();
    } catch (e) {
      _errorMessage = _cleanError(e);
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  // Open a conversation and load its messages.
  Future<void> loadMessages({
    required int otherUserId,
    required int currentUserId,
  }) async {
    _activeConversationUserId = otherUserId;
    _currentUserId = currentUserId;
    _isLoadingMessages = true;
    _errorMessage = null;
    _messages = [];
    notifyListeners();

    try {
      _messages = await _repository.getMessages(otherUserId);

      // Mark unread messages received by the current user as read.
      final unreadMessages = _messages.where(
        (message) => message.receiverId == currentUserId && !message.isRead,
      );

      for (final message in unreadMessages) {
        try {
          await _repository.markAsRead(message.messageId);
        } catch (_) {
          // Keep loading the conversation if one update fails.
        }
      }

      // Refresh messages to get the latest read status.
      if (unreadMessages.isNotEmpty) {
        _messages = await _repository.getMessages(otherUserId);
      }

      await loadConversations();
    } catch (e) {
      _errorMessage = _cleanError(e);
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  // Send a message and refresh the conversation.
  Future<bool> sendMessage(String text) async {
    final message = text.trim();
    final receiverId = _activeConversationUserId;
    final currentUserId = _currentUserId;

    if (message.isEmpty || receiverId == null || currentUserId == null) {
      return false;
    }

    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.sendMessage(receiverId: receiverId, message: message);

      _messages = await _repository.getMessages(receiverId);
      await loadConversations();

      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // Delete a message sent by the current user.
  Future<bool> deleteMessage(int messageId) async {
    final receiverId = _activeConversationUserId;

    if (receiverId == null) return false;

    try {
      await _repository.deleteMessage(messageId);

      _messages.removeWhere((message) => message.messageId == messageId);

      await loadConversations();
      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      notifyListeners();
      return false;
    }
  }

  // Refresh the currently open conversation.
  Future<void> refreshMessages() async {
    final receiverId = _activeConversationUserId;
    final currentUserId = _currentUserId;

    if (receiverId == null || currentUserId == null) return;

    await loadMessages(otherUserId: receiverId, currentUserId: currentUserId);
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
