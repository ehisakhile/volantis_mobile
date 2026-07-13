/// Represents a participant with their hand raised
class RaisedHand {
  final String identity;
  final String name;
  final int timestamp;

  RaisedHand({
    required this.identity,
    required this.name,
    required this.timestamp,
  });
}

/// LiveKit data channel topic for hand raise events
const String kHandRaiseTopic = 'hand-raise';

/// LiveKit participant attribute key for hand raise state (used for late-joiner sync)
const String kHandRaiseAttributeKey = 'hand-raised';

/// Simple in-memory persistence per room for raised hands
class RoomHandRaiseStore {
  static final Map<String, List<RaisedHand>> _store = {};

  static List<RaisedHand> getRaisedHands(String roomId) {
    return _store.putIfAbsent(roomId, () => []);
  }

  /// Upserts a raised hand (adds or updates if exists) and keeps list sorted by timestamp
  static void upsert(String roomId, RaisedHand hand) {
    final list = _store.putIfAbsent(roomId, () => []);
    list.removeWhere((h) => h.identity == hand.identity);
    list.add(hand);
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static void remove(String roomId, String identity) {
    _store[roomId]?.removeWhere((h) => h.identity == identity);
  }

  static void clear(String roomId) {
    _store.remove(roomId);
  }
}
