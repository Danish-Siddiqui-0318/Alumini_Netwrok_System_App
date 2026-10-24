class ConversationModel {
  final int otherUserId;
  final String otherUserName;
  final int? messageId;
  final String lastMessage;
  final int lastSenderId;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ConversationModel({
    required this.otherUserId,
    required this.otherUserName,
    this.messageId,
    required this.lastMessage,
    required this.lastSenderId,
    this.lastMessageAt,
    required this.unreadCount,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json,) {
    return ConversationModel(
      otherUserId: int.parse(
        json['other_user_id'].toString(),
      ),
      otherUserName:
      json['other_user_name']?.toString() ?? 'Unknown User',
      messageId: json['message_id'] == null
          ? null
          : int.tryParse(json['message_id'].toString()),
      lastMessage: json['last_message']?.toString() ?? '',
      lastSenderId: int.tryParse(
        json['last_sender_id'].toString(),
      ) ??
          0,
      lastMessageAt: json['last_message_at'] == null
          ? null
          : DateTime.tryParse(
        json['last_message_at'].toString(),
      ),
      unreadCount: int.tryParse(
        json['unread_count'].toString(),
      ) ??
          0,
    );
  }
}
