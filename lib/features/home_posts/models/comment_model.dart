class CommentModel {
  final int commentId;
  final int postId;
  final int userId;
  final String authorName;
  final String? authorProfilePicture;
  final String content;
  final String? createdAt;

  const CommentModel({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.authorName,
    this.authorProfilePicture,
    required this.content,
    this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      commentId: int.parse(json['comment_id'].toString()),
      postId: int.parse(json['post_id'].toString()),
      userId: int.parse(json['user_id'].toString()),
      authorName: json['author_name']?.toString() ?? 'Alumni',
      authorProfilePicture: json['author_profile_picture']?.toString(),
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
    );
  }

  CommentModel copyWith({String? content}) {
    return CommentModel(
      commentId: commentId,
      postId: postId,
      userId: userId,
      authorName: authorName,
      authorProfilePicture: authorProfilePicture,
      content: content ?? this.content,
      createdAt: createdAt,
    );
  }
}
