import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/auth_palette.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/conversation_model.dart';
import '../providers/message_provider.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MessageProvider>().loadConversations();
      }
    });
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final localTime = dateTime.toLocal();
    final now = DateTime.now();

    if (localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day) {
      final hour = localTime.hour % 12 == 0 ? 12 : localTime.hour % 12;
      final minute = localTime.minute.toString().padLeft(2, '0');
      final period = localTime.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    }

    return '${localTime.day}/${localTime.month}/${localTime.year}';
  }

  Future<void> _openChat(
    BuildContext context,
    ConversationModel conversation,
  ) async {
    final auth = context.read<AuthProvider>();
    final int? currentUserId = auth.currentUser?.userId;

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to identify the logged-in user. Please log in again.',
          ),
        ),
      );
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: conversation.otherUserId,
          otherUserName: conversation.otherUserName,
          currentUserId: currentUserId,
        ),
      ),
    );

    if (context.mounted) {
      await context.read<MessageProvider>().loadConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.mist,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AuthPalette.ink,
        foregroundColor: Colors.white,
      ),
      body: Consumer<MessageProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingConversations &&
              provider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null && provider.conversations.isEmpty) {
            return _StatusMessage(
              message: provider.errorMessage!,
              icon: Icons.cloud_off_rounded,
              onRetry: provider.loadConversations,
            );
          }

          if (provider.conversations.isEmpty) {
            return RefreshIndicator(
              onRefresh: provider.loadConversations,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  _StatusMessage(
                    message: 'Your conversations will appear here.',
                    icon: Icons.chat_bubble_outline_rounded,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.loadConversations,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: provider.conversations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final conversation = provider.conversations[index];

                final preview = conversation.lastMessage.isEmpty
                    ? 'Start a conversation'
                    : conversation.lastMessage;

                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openChat(context, conversation),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AuthPalette.ink,
                            child: Text(
                              conversation.otherUserName.isNotEmpty
                                  ? conversation.otherUserName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conversation.otherUserName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AuthPalette.ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: conversation.unreadCount > 0
                                        ? AuthPalette.ink
                                        : AuthPalette.textMuted,
                                    fontWeight: conversation.unreadCount > 0
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(conversation.lastMessageAt),
                                style: const TextStyle(
                                  color: AuthPalette.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 7),
                              if (conversation.unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AuthPalette.brass,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    conversation.unreadCount > 99
                                        ? '99+'
                                        : '${conversation.unreadCount}',
                                    style: const TextStyle(
                                      color: AuthPalette.ink,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final String message;
  final IconData icon;
  final Future<void> Function()? onRetry;

  const _StatusMessage({
    required this.message,
    required this.icon,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AuthPalette.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AuthPalette.textMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
