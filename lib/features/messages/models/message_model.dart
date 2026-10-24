class MessageModel {
  final int messageId;
  final int senderId;
  final int receiverId;
  final String message;
  final bool isRead;
  final DateTime? createdAt;
  final String? senderName;
  final String? receiverName;

  const MessageModel({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.isRead,
    this.createdAt,
    this.senderName,
    this.receiverName,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json,) {
    return MessageModel(
      messageId: int.parse(
        json['message_id'].toString(),
      ),
      senderId: int.parse(
        json['sender_id'].toString(),
      ),
      receiverId: int.parse(
        json['receiver_id'].toString(),
      ),
      message: json['message']?.toString() ?? '',
      isRead: json['is_read'] == true ||
          json['is_read'] == 1 ||
          json['is_read']?.toString() == '1',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(
        json['created_at'].toString(),
      ),
      senderName: json['sender_name']?.toString(),
      receiverName: json['receiver_name']?.toString(),
    );
  }
}
