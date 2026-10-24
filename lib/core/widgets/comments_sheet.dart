import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/auth_palette.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home_posts/models/comment_model.dart';
import '../../features/home_posts/providers/post_provider.dart';

/// Facebook-style comments panel that slides up over the feed.
///
/// Open it with:  CommentsSheet.show(context, post.postId);
class CommentsSheet extends StatefulWidget {
  final int postId;
  final ScrollController scrollController;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.scrollController,
  });

  /// Shows the sheet. Drag it up to expand, drag down (or tap outside) to close.
  static Future<void> show(BuildContext context, int postId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AuthPalette.ink.withOpacity(0.45),
      builder: (sheetContext) {
        // Lifts the sheet above the keyboard.
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            expand: false,
            snap: true,
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder: (_, scrollController) => CommentsSheet(
              postId: postId,
              scrollController: scrollController,
            ),
          ),
        );
      },
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  bool _sending = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PostProvider>().loadComments(widget.postId);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Snackbars must live inside the sheet, otherwise the sheet covers them.
  void _showError(String message) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AuthPalette.error,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Comment logic (unchanged)
  // ---------------------------------------------------------------------------

  Future<void> _sendComment() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);

    final success = await context.read<PostProvider>().addComment(
      postId: widget.postId,
      content: content,
    );

    if (!mounted) return;

    setState(() => _sending = false);

    if (success) {
      _controller.clear();
    } else {
      _showError(
        context.read<PostProvider>().errorMessage ?? 'Could not add comment.',
      );
    }
  }

  Future<void> _editComment(CommentModel comment) async {
    final controller = TextEditingController(text: comment.content);

    try {
      final content = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit comment',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AuthPalette.ink,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              filled: true,
              fillColor: AuthPalette.mist,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AuthPalette.ink,
                  width: 1.6,
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(foregroundColor: AuthPalette.ink),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AuthPalette.brass,
                foregroundColor: AuthPalette.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (content == null || !mounted) return;

      final success = await context.read<PostProvider>().editComment(
        postId: widget.postId,
        commentId: comment.commentId,
        content: content,
      );

      if (!mounted) return;

      if (!success) {
        _showError(
          context.read<PostProvider>().errorMessage ??
              'Could not update comment.',
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
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
          'Delete comment?',
          style: TextStyle(fontWeight: FontWeight.w800, color: AuthPalette.ink),
        ),
        content: const Text(
          'Are you sure you want to delete this comment?',
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

    final success = await context.read<PostProvider>().removeComment(
      postId: widget.postId,
      commentId: comment.commentId,
    );

    if (!mounted) return;

    if (!success) {
      _showError(
        context.read<PostProvider>().errorMessage ??
            'Could not delete comment.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ScaffoldMessenger(
        key: _messengerKey,
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: false, // the sheet already handles this
          body: Column(
            children: [
              Expanded(
                child: Consumer<PostProvider>(
                  builder: (context, provider, child) {
                    final comments = provider.commentsForPost(widget.postId);
                    final loading =
                        provider.areCommentsLoading(widget.postId) &&
                        comments.isEmpty;

                    return CustomScrollView(
                      controller: widget.scrollController,
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _HeaderDelegate(
                            count: comments.length,
                            onClose: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                        if (loading)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AuthPalette.ink,
                              ),
                            ),
                          )
                        else if (comments.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyComments(),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final comment = comments[index];
                                final userId = context
                                    .read<AuthProvider>()
                                    .currentUser
                                    ?.userId;
                                final isOwner = userId == comment.userId;

                                return _buildComment(comment, isOwner);
                              }, childCount: comments.length),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComment(CommentModel comment, bool isOwner) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            name: comment.authorName,
            imageUrl: comment.authorProfilePicture,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                decoration: BoxDecoration(
                  color: AuthPalette.mist,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AuthPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      comment.content,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        color: Color(0xFF1F2D3F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isOwner)
            PopupMenuButton<String>(
              tooltip: 'Comment options',
              color: Colors.white,
              elevation: 6,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(
                Icons.more_horiz_rounded,
                size: 22,
                color: AuthPalette.textMuted,
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  _editComment(comment);
                } else if (value == 'delete') {
                  _deleteComment(comment);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: AuthPalette.ink),
                      SizedBox(width: 12),
                      Text(
                        'Edit',
                        style: TextStyle(
                          color: AuthPalette.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        color: AuthPalette.error,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Delete',
                        style: TextStyle(
                          color: AuthPalette.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE6EBF1))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Write a comment...',
                    hintStyle: const TextStyle(color: AuthPalette.textMuted),
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
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _sendComment,
                tooltip: 'Send',
                style: IconButton.styleFrom(
                  backgroundColor: AuthPalette.brass,
                  foregroundColor: AuthPalette.ink,
                  disabledBackgroundColor: AuthPalette.brass.withOpacity(0.55),
                  fixedSize: const Size(48, 48),
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AuthPalette.ink,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinned top section: drag handle, title, count chip and close button.
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final int count;
  final VoidCallback onClose;

  _HeaderDelegate({required this.count, required this.onClose});

  @override
  double get minExtent => 76;

  @override
  double get maxExtent => 76;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE6EBF1))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD5DCE6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AuthPalette.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AuthPalette.ink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: AuthPalette.brass,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Close',
                    style: IconButton.styleFrom(
                      backgroundColor: AuthPalette.mist,
                      foregroundColor: AuthPalette.ink,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) =>
      oldDelegate.count != count;
}

class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AuthPalette.mist,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mode_comment_outlined,
              size: 32,
              color: AuthPalette.inkLight,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No comments yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AuthPalette.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start the conversation!',
            style: TextStyle(color: AuthPalette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasPicture = imageUrl != null && imageUrl!.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: 18,
      backgroundColor: AuthPalette.inkLight,
      backgroundImage: hasPicture ? NetworkImage(imageUrl!) : null,
      child: hasPicture
          ? null
          : Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
    );
  }
}
