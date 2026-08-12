/// Represents a single reaction emoji sent by a participant
class ReactionInstance {
  final String id;
  final String emoji;
  final String senderName;
  final int spawnedAt; // epoch ms

  ReactionInstance({
    required this.id,
    required this.emoji,
    required this.senderName,
    required this.spawnedAt,
  });

  Map<String, dynamic> toJson() => {
        'type': 'reaction',
        'id': id,
        'emoji': emoji,
        'name': senderName,
        'timestamp': spawnedAt,
      };

  factory ReactionInstance.fromJson(Map<String, dynamic> json) =>
      ReactionInstance(
        id: json['id'] as String,
        emoji: json['emoji'] as String,
        senderName: json['name'] as String? ?? 'Someone',
        spawnedAt: json['timestamp'] as int,
      );
}

/// LiveKit data channel topic for reactions
const String kReactionTopic = 'reaction';

/// Simple in-memory persistence per room for reactions
class RoomReactionStore {
  static final Map<String, List<ReactionInstance>> _store = {};

  static List<ReactionInstance> getReactions(String roomId) {
    return _store.putIfAbsent(roomId, () => []);
  }

  static void addReaction(String roomId, ReactionInstance reaction) {
    _store.putIfAbsent(roomId, () => []).add(reaction);
  }

  static void removeReaction(String roomId, String reactionId) {
    _store[roomId]?.removeWhere((r) => r.id == reactionId);
  }

  static void clear(String roomId) {
    _store.remove(roomId);
  }
}
