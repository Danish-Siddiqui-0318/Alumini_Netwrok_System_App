import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/auth_palette.dart';
import '../../../core/widgets/comments_sheet.dart';
import '../../../core/widgets/post_time_label.dart';
import '../../auth/providers/auth_provider.dart';
import '../../messages/providers/message_provider.dart';
import '../../messages/screens/chat_screen.dart';
import '../../profile/screens/public_profile_screen.dart';
import '../models/post_model.dart';
import '../providers/post_provider.dart';

/// Floating, icon-led snackbar shared by the whole feed.
void _showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AuthPalette.error : AuthPalette.ink,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

/// White rounded surface with a soft ink-tinted shadow.
BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    boxShadow: [
      BoxShadow(
        color: AuthPalette.ink.withOpacity(0.07),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

// =============================================================================
// Home screen
// =============================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PostProvider>().loadPosts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PostProvider>(
      builder: (context, provider, child) {
        final posts = provider.posts;

        return ColoredBox(
          color: AuthPalette.mist,
          child: RefreshIndicator(
            color: AuthPalette.ink,
            onRefresh: provider.loadPosts,
            // Slivers build post cards lazily, so long feeds stay smooth.
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(child: _Composer()),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 24, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Latest from your community',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AuthPalette.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                if (provider.isLoading && posts.isEmpty)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 28),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _PostSkeleton(),
                          _PostSkeleton(),
                          _PostSkeleton(),
                        ],
                      ),
                    ),
                  )
                else if (provider.errorMessage != null && posts.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    sliver: SliverToBoxAdapter(
                      child: _StateCard(
                        icon: Icons.cloud_off_rounded,
                        title: 'Something went wrong',
                        message: provider.errorMessage!,
                        actionLabel: 'Try again',
                        onAction: provider.loadPosts,
                      ),
                    ),
                  )
                else if (posts.isEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 28),
                      sliver: SliverToBoxAdapter(
                        child: _StateCard(
                          icon: Icons.forum_outlined,
                          title: 'No posts yet',
                          message:
                          'Be the first to share something with the '
                              'community.',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final post = posts[index];
                            return _PostCard(
                              key: ValueKey(post.postId),
                              post: post,
                            );
                          },
                          childCount: posts.length,
                          findChildIndexCallback: (key) {
                            if (key is ValueKey<int>) {
                              final index = posts.indexWhere(
                                    (p) => p.postId == key.value,
                              );
                              return index == -1 ? null : index;
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Composer (compact until you tap it)
// =============================================================================

class _Composer extends StatefulWidget {
  const _Composer();

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;

  bool get _hasContent =>
      _controller.text.trim().isNotEmpty || _selectedImage != null;

  /// Expanded while focused or while there is something to post.
  bool get _expanded => _focus.hasFocus || _hasContent;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    _focus.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null && mounted) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _submitPost() async {
    if (_controller.text.trim().isEmpty && _selectedImage == null) {
      _showSnack(
        context,
        'Write something or select an image first.',
        error: true,
      );
      return;
    }
    FocusScope.of(context).unfocus();

    final provider = context.read<PostProvider>();

    final success = await provider.createPost(
      content: _controller.text.trim(),
      image: _selectedImage,
    );

    if (!mounted) return;

    if (success) {
      _controller.clear();
      setState(() => _selectedImage = null);
      _showSnack(context, 'Post published successfully.');
    } else {
      _showSnack(
        context,
        provider.errorMessage ?? 'Could not publish post.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final creating = context.select<PostProvider, bool>((p) => p.isCreating);
    final expanded = _expanded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: expanded
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: expanded ? 4 : 0),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AuthPalette.brass,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 20,
                      color: AuthPalette.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    enabled: !creating,
                    minLines: expanded ? 3 : 1,
                    maxLines: expanded ? 6 : 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: expanded
                          ? 'Share something with your alumni community...'
                          : "What's on your mind?",
                      hintStyle: const TextStyle(color: AuthPalette.textMuted),
                      filled: true,
                      fillColor: AuthPalette.mist,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: expanded ? 14 : 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AuthPalette.ink,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!expanded) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Add photo',
                    onPressed: creating ? null : _pickImage,
                    icon: const Icon(
                      Icons.image_outlined,
                      color: AuthPalette.inkLight,
                    ),
                  ),
                ],
              ],
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 12),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _selectedImage!,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: AuthPalette.ink.withOpacity(0.75),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: creating
                            ? null
                            : () => setState(() => _selectedImage = null),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (expanded) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: creating ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined, size: 20),
                    label: Text(_selectedImage == null ? 'Photo' : 'Change'),
                    style: TextButton.styleFrom(
                      foregroundColor: AuthPalette.ink,
                      backgroundColor: AuthPalette.mist,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: creating || !_hasContent ? null : _submitPost,
                    style: FilledButton.styleFrom(
                      backgroundColor: AuthPalette.brass,
                      foregroundColor: AuthPalette.ink,
                      disabledBackgroundColor: creating
                          ? AuthPalette.brass.withOpacity(0.55)
                          : AuthPalette.mist,
                      disabledForegroundColor: creating
                          ? AuthPalette.ink
                          : AuthPalette.textMuted,
                      minimumSize: const Size(96, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: creating
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AuthPalette.ink,
                      ),
                    )
                        : const Text('Post'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// States
// =============================================================================

/// Used for the error and empty states.
class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AuthPalette.mist,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AuthPalette.inkLight),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
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
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AuthPalette.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pulsing placeholder shown while the first posts load.
class _PostSkeleton extends StatefulWidget {
  const _PostSkeleton();

  @override
  State<_PostSkeleton> createState() => _PostSkeletonState();
}

class _PostSkeletonState extends State<_PostSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  static const _bar = Color(0xFFE6EBF1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _line({double? width, double height = 12}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _bar,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: _bar,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(width: 130, height: 14),
                    const SizedBox(height: 8),
                    _line(width: 80, height: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            _line(),
            const SizedBox(height: 10),
            _line(),
            const SizedBox(height: 10),
            _line(width: 200),
            const SizedBox(height: 18),
            _line(height: 36),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Post card
// =============================================================================

class _PostCard extends StatelessWidget {
  final PostModel post;

  const _PostCard({super.key, required this.post});

  void _openPublicProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: post.userId),
      ),
    );
  }

  Future<void> _openChat(BuildContext context, int currentUserId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: post.userId,
          otherUserName: post.authorName,
          currentUserId: currentUserId,
        ),
      ),
    );

    if (context.mounted) {
      await context.read<MessageProvider>().loadConversations();
    }
  }

  /// Full-screen, pinch-to-zoom view of the post image.
  void _openImage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ImageViewer(
          url: post.imageUrl!,
          heroTag: 'post-image-${post.postId}',
        ),
      ),
    );
  }

  Future<void> _editPost(BuildContext context) async {
    final controller = TextEditingController(text: post.content);

    try {
      final newContent = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Edit post',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AuthPalette.ink,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'What would you like to share?',
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
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(foregroundColor: AuthPalette.ink),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final content = controller.text.trim();

                  if (content.isNotEmpty) {
                    Navigator.of(dialogContext).pop(content);
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
          );
        },
      );

      if (newContent == null || !context.mounted) return;

      final provider = context.read<PostProvider>();

      final success = await provider.updatePost(
        postId: post.postId,
        content: newContent,
      );

      if (!context.mounted) return;

      _showSnack(
        context,
        success
            ? 'Post updated successfully.'
            : provider.errorMessage ?? 'Could not update post.',
        error: !success,
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deletePost(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AuthPalette.error,
            size: 32,
          ),
          title: const Text(
            'Delete post?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AuthPalette.ink,
            ),
          ),
          content: const Text(
            'Are you sure you want to delete this post? '
                'This action cannot be undone.',
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
              style: FilledButton.styleFrom(
                backgroundColor: AuthPalette.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final provider = context.read<PostProvider>();
    final success = await provider.deletePost(post.postId);

    if (!context.mounted) return;

    _showSnack(
      context,
      success
          ? 'Post deleted successfully.'
          : provider.errorMessage ?? 'Could not delete post.',
      error: !success,
    );
  }

  Widget _buildAvatar() {
    final hasPicture =
        post.authorProfilePicture != null &&
            post.authorProfilePicture!.isNotEmpty;
    final initial = post.authorName.isNotEmpty
        ? post.authorName[0].toUpperCase()
        : '?';

    // Brass ring around the avatar.
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: AuthPalette.brass,
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: AuthPalette.inkLight,
        backgroundImage: hasPicture
            ? NetworkImage(post.authorProfilePicture!)
            : null,
        child: hasPicture
            ? null
            : Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // select() rebuilds this card only when its own like state / user changes.
    final liked = context.select<PostProvider, bool>(
          (p) => p.likedPosts[post.postId] ?? false,
    );
    final currentUserId = context.select<AuthProvider, int?>(
          (a) => a.currentUser?.userId,
    );

    // Compare the logged-in user's ID with the post owner's ID.
    final isOwner = currentUserId == post.userId;

    final hasStats = post.likeCount > 0 || post.commentCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => _openPublicProfile(context),
                customBorder: const CircleBorder(),
                child: _buildAvatar(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _openPublicProfile(context),
                      child: Text(
                        post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: AuthPalette.ink,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: PostTimeLabel(createdAt: post.createdAt),
                    ),
                  ],
                ),
              ),

              // Edit/Delete menu for the owner's posts only.
              if (isOwner)
                PopupMenuButton<String>(
                  tooltip: 'Post options',
                  color: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AuthPalette.textMuted,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editPost(context);
                    } else if (value == 'delete') {
                      _deletePost(context);
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
                            'Edit post',
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
                            'Delete post',
                            style: TextStyle(
                              color: AuthPalette.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ExpandableText(text: post.content),
          ],

          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => _openImage(context),
              child: Hero(
                tag: 'post-image-${post.postId}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    post.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;

                      return Container(
                        height: 190,
                        color: AuthPalette.mist,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AuthPalette.ink,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 110,
                        color: AuthPalette.mist,
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                color: AuthPalette.textMuted,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Could not load image',
                                style: TextStyle(color: AuthPalette.textMuted),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],

          // Counts only appear once there is something to count.
          if (hasStats) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (post.likeCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AuthPalette.ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.thumb_up_rounded,
                      size: 11,
                      color: AuthPalette.brass,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    post.likeCount == 1 ? '1 like' : '${post.likeCount} likes',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AuthPalette.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                if (post.commentCount > 0)
                // Tapping the count opens the comments.
                  InkWell(
                    onTap: () => CommentsSheet.show(context, post.postId),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        post.commentCount == 1
                            ? '1 comment'
                            : '${post.commentCount} comments',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AuthPalette.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],

          Padding(
            padding: EdgeInsets.only(top: hasStats ? 10 : 14, bottom: 10),
            child: const Divider(height: 1, color: Color(0xFFE6EBF1)),
          ),

          Row(
            children: [
              Expanded(
                child: _PostAction(
                  icon: liked
                      ? Icons.thumb_up_rounded
                      : Icons.thumb_up_outlined,
                  label: liked ? 'Liked' : 'Like',
                  active: liked,
                  onPressed: () =>
                      context.read<PostProvider>().toggleLike(post),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _PostAction(
                  icon: Icons.mode_comment_outlined,
                  label: 'Comment',
                  onPressed: () => CommentsSheet.show(context, post.postId),
                ),
              ),
              if (!isOwner) ...[
                const SizedBox(width: 4),
                Expanded(
                  child: _PostAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Message',
                    onPressed: () {
                      final userId = context
                          .read<AuthProvider>()
                          .currentUser
                          ?.userId;

                      if (userId == null) {
                        _showSnack(
                          context,
                          'Please log in to send a message.',
                          error: true,
                        );
                        return;
                      }

                      _openChat(context, userId);
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Long posts are cut after 6 lines with a "Read more" toggle.
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const _maxLines = 6;
  static const _style = TextStyle(
    fontSize: 15.5,
    height: 1.5,
    color: Color(0xFF1F2D3F),
  );

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: _style),
          maxLines: _maxLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);

        // Short posts render exactly as before.
        if (!painter.didExceedMaxLines) {
          return Text(widget.text, style: _style);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: _style,
              maxLines: _expanded ? null : _maxLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _expanded ? 'Show less' : 'Read more',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AuthPalette.inkLight,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Full-screen image with pinch-to-zoom.
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url, required this.heroTag});

  final String url;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Hero(
            tag: heroTag,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;

                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped action button; tinted when [active].
class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AuthPalette.ink : AuthPalette.textMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: active ? AuthPalette.ink.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        // FittedBox keeps three buttons readable on narrow phones.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The icon "pops" when it switches (e.g. Like -> Liked).
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(icon, key: ValueKey(icon), size: 20, color: color),
              ),
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}