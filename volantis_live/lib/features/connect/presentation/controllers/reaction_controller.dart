import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../models/reaction_instance.dart';

/// Controller managing reactions in a LiveKit room
/// Handles sending, receiving, and auto-expiring reactions
class ReactionController extends ChangeNotifier {
  ReactionController({required this.room}) {
    _listener = room.createListener();
    _listener.on<DataReceivedEvent>(_handleDataReceived);
  }

  final Room room;
  late final EventsListener<RoomEvent> _listener;
  final Map<String, Timer> _expiryTimers = {};

  /// Get active reactions for this room
  List<ReactionInstance> get activeReactions =>
      List.unmodifiable(RoomReactionStore.getReactions(room.name ?? ''));

  /// Send a reaction emoji
  Future<void> sendReaction(String emoji) async {
    final localIdentity = room.localParticipant?.identity ?? 'local';
    final localName = room.localParticipant?.name ?? 'You';

    final reaction = ReactionInstance(
      id: '${DateTime.now().millisecondsSinceEpoch}-'
          '${(1000 + (900 * (DateTime.now().microsecond / 1000000))).toInt()}',
      emoji: emoji,
      senderName: localName.isNotEmpty ? localName : localIdentity,
      spawnedAt: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      final bytes = utf8.encode(jsonEncode(reaction.toJson()));
      await room.localParticipant?.publishData(
        bytes,
        topic: kReactionTopic,
      );
    } catch (e) {
      debugPrint('❌ Failed to send reaction: $e');
      rethrow;
    }

    _addAndScheduleExpiry(reaction);
  }

  /// Handle incoming reactions from other participants
  void _handleDataReceived(DataReceivedEvent event) {
    if (event.topic != kReactionTopic) return;

    try {
      final json = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
      if (json['type'] != 'reaction') return;

      final reaction = ReactionInstance.fromJson(json);
      _addAndScheduleExpiry(reaction);
    } catch (e) {
      debugPrint('❌ Failed to parse incoming reaction: $e');
    }
  }

  /// Add reaction to store and schedule auto-removal after 3 seconds
  void _addAndScheduleExpiry(ReactionInstance reaction) {
    RoomReactionStore.addReaction(room.name ?? '', reaction);
    notifyListeners();

    _expiryTimers[reaction.id] = Timer(const Duration(seconds: 3), () {
      RoomReactionStore.removeReaction(room.name ?? '', reaction.id);
      _expiryTimers.remove(reaction.id);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    for (final t in _expiryTimers.values) {
      t.cancel();
    }
    _expiryTimers.clear();
    _listener.dispose();
    super.dispose();
  }
}
