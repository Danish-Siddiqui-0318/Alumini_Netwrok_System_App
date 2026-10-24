import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/auth_palette.dart';
import '../../../core/widgets/comments_sheet.dart';
import '../../../core/widgets/post_time_label.dart';
import '../../auth/providers/auth_provider.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _postController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;

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
  void dispose() {
    _postController.dispose();
    super.dispose();
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
    if (_postController.text.trim().isEmpty && _selectedImage == null) {
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
      content: _postController.text.trim(),
      image: _selectedImage,
    );

    if (!mounted) return;

    if (success) {
      _postController.clear();
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
    return Consumer<PostProvider>(
      builder: (context, provider, child) {
        return ColoredBox(
          color: AuthPalette.mist,
          child: RefreshIndicator(
            color: AuthPalette.ink,
            onRefresh: provider.loadPosts,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _buildComposer(provider),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
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
                if (provider.isLoading && provider.posts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: AuthPalette.ink),
                    ),
                  )
                else if (provider.errorMessage != null &&
                    provider.posts.isEmpty)
                  _StateCard(
                    icon: Icons.cloud_off_rounded,
                    title: 'Something went wrong',
                    message: provider.errorMessage!,
                    actionLabel: 'Try again',
                    onAction: provider.loadPosts,
                  )
                else if (provider.posts.isEmpty)
                  const _StateCard(
                    icon: Icons.forum_outlined,
                    title: 'No posts yet',
                    message:
                        'Be the first to share something with the '
                        'community.',
                  )
                else
                  ...provider.posts.map((post) => _PostCard(post: post)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer(PostProvider provider) {
    final creating = provider.isCreating;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AuthPalette.brass,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: AuthPalette.ink,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Share with your alumni community',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AuthPalette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _postController,
            enabled: !creating,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: "What's on your mind?",
              hintStyle: const TextStyle(color: AuthPalette.textMuted),
              filled: true,
              fillColor: AuthPalette.mist,
              contentPadding: const EdgeInsets.all(16),
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
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton.icon(
                onPressed: creating ? null : _pickImage,
                icon: const Icon(Icons.image_outlined, size: 20),
                label: const Text('Photo'),
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
                onPressed: creating ? null : _submitPost,
                style: FilledButton.styleFrom(
                  backgroundColor: AuthPalette.brass,
                  foregroundColor: AuthPalette.ink,
                  disabledBackgroundColor: AuthPalette.brass.withOpacity(0.55),
                  disabledForegroundColor: AuthPalette.ink,
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
      ),
    );
  }
}

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

class _PostCard extends StatelessWidget {
  final PostModel post;

  const _PostCard({required this.post});

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
    final provider = context.watch<PostProvider>();
    final currentUser = context.watch<AuthProvider>().currentUser;
    final liked = provider.likedPosts[post.postId] ?? false;

    // Compare the logged-in user's ID with the post owner's ID.
    final isOwner = currentUser?.userId == post.userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AuthPalette.ink,
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
            Text(
              post.content,
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.5,
                color: Color(0xFF1F2D3F),
              ),
            ),
          ],

          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
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
                      child: CircularProgressIndicator(color: AuthPalette.ink),
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
          ],

          const SizedBox(height: 14),
          Row(
            children: [
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
              const Spacer(),
              Text(
                post.commentCount == 1
                    ? '1 comment'
                    : '${post.commentCount} comments',
                style: const TextStyle(
                  fontSize: 13,
                  color: AuthPalette.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFE6EBF1)),
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
                  onPressed: () => provider.toggleLike(post),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PostAction(
                  icon: Icons.mode_comment_outlined,
                  label: 'Comment',
                  onPressed: () => CommentsSheet.show(context, post.postId),
                ),
              ),
            ],
          ),
        ],
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
      child: TextButton.icon(
        onPressed: onPressed,
        // The icon "pops" when it switches (e.g. Like -> Liked).
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(icon, key: ValueKey(icon), size: 20, color: color),
        ),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontSize: 14.5,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
