import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const _unreadTint = Color(0xFFF0F4FA);
  static const _divider = Color(0xFFE9EDF3);

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MessageProvider>().loadConversations();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------------------

  /// Today -> "3:42 PM", yesterday -> "Yesterday", this week -> "Mon",
  /// older -> "24 Oct" (with the year when it is not this year).
  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final localTime = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(localTime.year, localTime.month, localTime.day);
    final diff = today.difference(day).inDays;

    if (diff <= 0) {
      final hour = localTime.hour % 12 == 0 ? 12 : localTime.hour % 12;
      final minute = localTime.minute.toString().padLeft(2, '0');
      final period = localTime.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    }
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return _weekdays[localTime.weekday - 1];
    if (localTime.year == now.year) {
      return '${localTime.day} ${_months[localTime.month - 1]}';
    }
    return '${localTime.day} ${_months[localTime.month - 1]} ${localTime.year}';
  }

  Future<void> _openChat(
    BuildContext context,
    ConversationModel conversation,
  ) async {
    final auth = context.read<AuthProvider>();
    final int? currentUserId = auth.currentUser?.userId;

    if (currentUserId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AuthPalette.error,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Unable to identify the logged-in user. '
                    'Please log in again.',
                  ),
                ),
              ],
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

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AuthPalette.mist,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AuthPalette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      title: Consumer<MessageProvider>(
        builder: (context, provider, child) {
          final totalUnread = provider.conversations.fold<int>(
            0,
            (sum, c) => sum + c.unreadCount,
          );

          return Row(
            children: [
              const Text(
                'Messages',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AuthPalette.ink,
                ),
              ),
              if (totalUnread > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AuthPalette.brass,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    totalUnread > 99 ? '99+' : '$totalUnread',
                    style: const TextStyle(
                      color: AuthPalette.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.mist,
      appBar: _buildAppBar(),
      body: Consumer<MessageProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingConversations &&
              provider.conversations.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AuthPalette.ink),
            );
          }

          if (provider.errorMessage != null && provider.conversations.isEmpty) {
            return _StatusMessage(
              title: 'Something went wrong',
              message: provider.errorMessage!,
              icon: Icons.cloud_off_rounded,
              onRetry: provider.loadConversations,
            );
          }

          if (provider.conversations.isEmpty) {
            return RefreshIndicator(
              color: AuthPalette.ink,
              onRefresh: provider.loadConversations,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 90),
                  _StatusMessage(
                    title: 'No conversations yet',
                    message: 'Your conversations will appear here.',
                    icon: Icons.chat_bubble_outline_rounded,
                  ),
                ],
              ),
            );
          }

          final query = _query.toLowerCase();
          final visible = query.isEmpty
              ? provider.conversations
              : provider.conversations
                    .where((c) => c.otherUserName.toLowerCase().contains(query))
                    .toList();

          return Column(
            children: [
              _buildSearchField(),
              Expanded(
                child: RefreshIndicator(
                  color: AuthPalette.ink,
                  onRefresh: provider.loadConversations,
                  child: visible.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 70),
                            _StatusMessage(
                              title: 'No matches',
                              message: 'No conversation matches "$_query".',
                              icon: Icons.search_off_rounded,
                            ),
                          ],
                        )
                      : _buildList(context, visible),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value.trim()),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search conversations',
          hintStyle: const TextStyle(color: AuthPalette.textMuted),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AuthPalette.textMuted,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AuthPalette.textMuted,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AuthPalette.ink, width: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<ConversationModel> items) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AuthPalette.ink.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _buildRow(context, items[i]),
                  if (i != items.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 84,
                      color: _divider,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, ConversationModel conversation) {
    final unread = conversation.unreadCount > 0;
    final preview = conversation.lastMessage.isEmpty
        ? 'Start a conversation'
        : conversation.lastMessage;

    return Material(
      color: unread ? _unreadTint : Colors.white,
      child: InkWell(
        onTap: () => _openChat(context, conversation),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              _ConversationAvatar(
                name: conversation.otherUserName,
                highlighted: unread,
              ),
              const SizedBox(width: 14),
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
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: conversation.lastMessage.isEmpty
                            ? AuthPalette.textMuted.withOpacity(0.8)
                            : unread
                            ? AuthPalette.ink
                            : AuthPalette.textMuted,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        fontStyle: conversation.lastMessage.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(conversation.lastMessageAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                      color: unread
                          ? AuthPalette.inkLight
                          : AuthPalette.textMuted,
                    ),
                  ),
                  if (unread) ...[
                    const SizedBox(height: 7),
                    Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AuthPalette.brass,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        conversation.unreadCount > 99
                            ? '99+'
                            : '${conversation.unreadCount}',
                        style: const TextStyle(
                          color: AuthPalette.ink,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Initial avatar; the color is picked from the name so each person keeps
/// the same color. A brass ring marks unread conversations.
class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.name, required this.highlighted});

  final String name;
  final bool highlighted;

  static const _colors = [
    AuthPalette.ink,
    AuthPalette.inkLight,
    Color(0xFF2E6F95),
    Color(0xFF3A7D6B),
    Color(0xFF6B4E9B),
  ];

  @override
  Widget build(BuildContext context) {
    final color = name.isEmpty
        ? _colors.first
        : _colors[name.codeUnits.fold<int>(0, (a, b) => a + b) %
              _colors.length];

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: highlighted ? AuthPalette.brass : Colors.transparent,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 25,
        backgroundColor: color,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Future<void> Function()? onRetry;

  const _StatusMessage({
    required this.title,
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
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AuthPalette.inkLight),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AuthPalette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AuthPalette.textMuted, height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AuthPalette.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
