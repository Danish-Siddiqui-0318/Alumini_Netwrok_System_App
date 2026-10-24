class PostModel {
  final int postId;
  final int userId;
  final String authorName;
  final String? authorProfilePicture;
  final String content;
  final String? imageUrl;
  final String? createdAt;
  final int likeCount;
  final int commentCount;

  const PostModel({
    required this.postId,
    required this.userId,
    required this.authorName,
    this.authorProfilePicture,
    required this.content,
    this.imageUrl,
    this.createdAt,
    required this.likeCount,
    required this.commentCount,
  });

  PostModel copyWith({int? likeCount, int? commentCount}) {
    return PostModel(
      postId: postId,
      userId: userId,
      authorName: authorName,
      authorProfilePicture: authorProfilePicture,
      content: content,
      imageUrl: imageUrl,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
    );
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      postId: int.parse(json['post_id'].toString()),
      userId: int.parse(json['user_id'].toString()),
      authorName: json['author_name']?.toString() ?? 'Alumni Network User',
      authorProfilePicture: json['author_profile_picture']?.toString(),
      content: json['content']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      createdAt: json['created_at']?.toString(),
      likeCount: int.tryParse(json['like_count']?.toString() ?? '0') ?? 0,
      commentCount: int.tryParse(json['comment_count']?.toString() ?? '0') ?? 0,
    );
  }
}
