import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/auth_palette.dart';
import '../models/message_model.dart';
import '../providers/message_provider.dart';

class ChatScreen extends StatefulWidget {
  final int otherUserId;
  final String otherUserName;
  final int currentUserId;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  /// Shows the "jump to latest" button when the user has scrolled up.
  final ValueNotifier<bool> _showJumpButton = ValueNotifier<bool>(false);

  int _lastMessageCount = 0;

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

  static const _avatarColors = [
    AuthPalette.ink,
    AuthPalette.inkLight,
    Color(0xFF2E6F95),
    Color(0xFF3A7D6B),
    Color(0xFF6B4E9B),
  ];

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    // When the keyboard opens, keep the latest message in view.
    _inputFocus.addListener(() {
      if (_inputFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _scrollToBottom();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MessageProvider>().loadMessages(
          otherUserId: widget.otherUserId,
          currentUserId: widget.currentUserId,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _showJumpButton.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Scrolling
  // ---------------------------------------------------------------------------

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final show = position.maxScrollExtent - position.pixels > 300;

    if (show != _showJumpButton.value) {
      _showJumpButton.value = show;
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;

    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 140;
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      if (jump) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        // Second pass: list extents are refined after the first layout.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      } else {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Only auto-scroll when it makes sense: first load, my own new message, or
  /// the user is already near the bottom. Otherwise reading old messages would
  /// be interrupted every time the list refreshes.
  void _handleMessagesChanged(List<MessageModel> messages) {
    final count = messages.length;
    if (count == _lastMessageCount) return;

    final firstLoad = _lastMessageCount == 0;
    _lastMessageCount = count;

    if (firstLoad) {
      _scrollToBottom(jump: true);
    } else if (messages.last.senderId == widget.currentUserId ||
        _isNearBottom) {
      _scrollToBottom();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dayLabel(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;

    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (local.year == now.year) {
      return '${local.day} ${_months[local.month - 1]}';
    }
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  /// Messages from the same person within 3 minutes are visually grouped.
  bool _sameGroup(MessageModel a, MessageModel b) {
    if (a.senderId != b.senderId) return false;

    final at = a.createdAt?.toLocal();
    final bt = b.createdAt?.toLocal();
    if (at == null || bt == null) return true;

    return _isSameDay(at, bt) && bt.difference(at).inMinutes.abs() < 3;
  }

  Color _avatarColor(String name) {
    if (name.isEmpty) return _avatarColors.first;
    final sum = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return _avatarColors[sum % _avatarColors.length];
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? AuthPalette.error : AuthPalette.ink,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Icon(
                error ? Icons.error_outline : Icons.check_circle_outline,
                color: error ? Colors.white : AuthPalette.brass,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Actions (send / delete logic unchanged)
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    final provider = context.read<MessageProvider>();
    final success = await provider.sendMessage(text);

    if (!mounted) return;

    if (success) {
      _messageController.clear();
      _scrollToBottom();
    } else {
      _showSnack(
        provider.errorMessage ?? 'Unable to send message.',
        error: true,
      );
    }
  }

  Future<void> _deleteMessage(MessageModel message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: AuthPalette.error,
          size: 32,
        ),
        title: const Text(
          'Delete message?',
          style: TextStyle(fontWeight: FontWeight.w800, color: AuthPalette.ink),
        ),
        content: const Text(
          'This message will be permanently deleted.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AuthPalette.textMuted, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: AuthPalette.ink),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AuthPalette.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await context.read<MessageProvider>().deleteMessage(
      message.messageId,
    );

    if (!mounted) return;

    _showSnack(
      success ? 'Message deleted.' : 'Unable to delete message.',
      error: !success,
    );
  }

  /// Long-press menu: copy for every message, delete for my own.
  Future<void> _showMessageActions(MessageModel message, bool isMine) async {
    HapticFeedback.mediumImpact();

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DCE6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(
                    Icons.copy_rounded,
                    color: AuthPalette.ink,
                  ),
                  title: const Text(
                    'Copy text',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AuthPalette.ink,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'copy'),
                ),
                if (isMine)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AuthPalette.error,
                    ),
                    title: const Text(
                      'Delete message',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AuthPalette.error,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'delete'),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.message));
      if (mounted) _showSnack('Message copied.');
    } else if (action == 'delete') {
      await _deleteMessage(message);
    }
  }

  void _useSuggestion(String text) {
    _messageController.text = text;
    _messageController.selection = TextSelection.collapsed(offset: text.length);
    _inputFocus.requestFocus();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AuthPalette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleSpacing: 0,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFE9EDF3)),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: _avatarColor(widget.otherUserName),
            child: Text(
              widget.otherUserName.isNotEmpty
                  ? widget.otherUserName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.otherUserName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AuthPalette.ink,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            tooltip: 'Refresh messages',
            style: IconButton.styleFrom(
              backgroundColor: AuthPalette.mist,
              foregroundColor: AuthPalette.ink,
            ),
            onPressed: () {
              context.read<MessageProvider>().refreshMessages();
            },
            icon: const Icon(Icons.refresh_rounded, size: 22),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.mist,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Consumer<MessageProvider>(
                  builder: (context, provider, child) {
                    return _buildMessagesArea(provider);
                  },
                ),
                Positioned(
                  right: 16,
                  bottom: 12,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _showJumpButton,
                    builder: (context, show, child) {
                      return AnimatedScale(
                        scale: show ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Material(
                          color: Colors.white,
                          elevation: 4,
                          shadowColor: AuthPalette.ink.withOpacity(0.3),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: show ? () => _scrollToBottom() : null,
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AuthPalette.ink,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessagesArea(MessageProvider provider) {
    if (provider.isLoadingMessages && provider.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AuthPalette.ink),
      );
    }

    if (provider.errorMessage != null && provider.messages.isEmpty) {
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
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 40,
                  color: AuthPalette.inkLight,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AuthPalette.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AuthPalette.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  provider.loadMessages(
                    otherUserId: widget.otherUserId,
                    currentUserId: widget.currentUserId,
                  );
                },
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
          ),
        ),
      );
    }

    if (provider.messages.isEmpty) {
      return _buildEmptyState();
    }

    _handleMessagesChanged(provider.messages);

    final messages = provider.messages;

    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final previous = index > 0 ? messages[index - 1] : null;
        final next = index < messages.length - 1 ? messages[index + 1] : null;

        final currentTime = message.createdAt?.toLocal();
        final previousTime = previous?.createdAt?.toLocal();

        final showDate =
            currentTime != null &&
            (previousTime == null || !_isSameDay(previousTime, currentTime));

        final endsGroup = next == null || !_sameGroup(message, next);
        final isMine = message.senderId == widget.currentUserId;

        return Column(
          children: [
            if (showDate) _DateChip(label: _dayLabel(currentTime)),
            _buildBubble(message, isMine: isMine, endsGroup: endsGroup),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    const suggestions = ['Hi 👋', 'How are you?', 'Can we connect?'];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AuthPalette.brass,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 38,
                backgroundColor: _avatarColor(widget.otherUserName),
                child: Text(
                  widget.otherUserName.isNotEmpty
                      ? widget.otherUserName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Say hello to ${widget.otherUserName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AuthPalette.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No messages yet. Start the conversation!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AuthPalette.textMuted),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final text in suggestions)
                  ActionChip(
                    label: Text(text),
                    onPressed: () => _useSuggestion(text),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFD5DCE6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AuthPalette.ink,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(
    MessageModel message, {
    required bool isMine,
    required bool endsGroup,
  }) {
    // Only the last bubble of a group gets the "tail" corner and the time.
    const big = Radius.circular(18);
    const tail = Radius.circular(5);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(message, isMine),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          margin: EdgeInsets.only(bottom: endsGroup ? 12 : 3),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
          decoration: BoxDecoration(
            color: isMine ? AuthPalette.ink : Colors.white,
            border: isMine
                ? null
                : Border.all(color: const Color(0xFFE6EBF1), width: 1),
            borderRadius: BorderRadius.only(
              topLeft: big,
              topRight: big,
              bottomLeft: isMine ? big : (endsGroup ? tail : big),
              bottomRight: isMine ? (endsGroup ? tail : big) : big,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message.message,
                  style: TextStyle(
                    color: isMine ? Colors.white : AuthPalette.ink,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ),
              if (endsGroup) ...[
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        color: isMine ? Colors.white70 : AuthPalette.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isRead
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 15,
                        color: message.isRead
                            ? AuthPalette.brass
                            : Colors.white70,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9EDF3))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _inputFocus,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 5000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Write a message...',
                    hintStyle: const TextStyle(color: AuthPalette.textMuted),
                    counterText: '',
                    filled: true,
                    fillColor: AuthPalette.mist,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: AuthPalette.ink,
                        width: 1.6,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              // Rebuilds on typing (has text?) and on sending state.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _messageController,
                builder: (context, value, child) {
                  final hasText = value.text.trim().isNotEmpty;

                  return Consumer<MessageProvider>(
                    builder: (context, provider, child) {
                      final enabled = hasText && !provider.isSending;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: hasText ? AuthPalette.brass : AuthPalette.mist,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Send message',
                          onPressed: enabled ? _sendMessage : null,
                          style: IconButton.styleFrom(
                            fixedSize: const Size(48, 48),
                          ),
                          icon: provider.isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AuthPalette.ink,
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  size: 22,
                                  color: hasText
                                      ? AuthPalette.ink
                                      : AuthPalette.textMuted,
                                ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered day label between messages ("Today", "Yesterday", "24 Oct").
class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE3E9F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AuthPalette.textMuted,
          ),
        ),
      ),
    );
  }
}
