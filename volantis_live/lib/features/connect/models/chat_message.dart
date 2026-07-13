/// Represents a chat message in a LiveKit room
class LKChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final int timestamp;

  LKChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'message': message,
    'timestamp': timestamp,
  };

  factory LKChatMessage.fromJson(Map<String, dynamic> json) {
    return LKChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      message: json['message'] as String,
      timestamp: json['timestamp'] as int,
    );
  }
}
