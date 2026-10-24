class NotificationModel {
  final int notificationId;
  final int userId;
  final String type;
  final String message;
  final int? referenceId;
  final bool isRead;
  final DateTime? createdAt;

  const NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.message,
    this.referenceId,
    required this.isRead,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: int.parse(json['notification_id'].toString()),
      userId: int.parse(json['user_id'].toString()),
      type: json['type']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      referenceId: json['reference_id'] == null
          ? null
          : int.tryParse(json['reference_id'].toString()),
      isRead:
          json['is_read'] == true ||
          json['is_read'] == 1 ||
          json['is_read']?.toString() == '1' ||
          json['is_read']?.toString().toLowerCase() == 'true',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      notificationId: notificationId,
      userId: userId,
      type: type,
      message: message,
      referenceId: referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
