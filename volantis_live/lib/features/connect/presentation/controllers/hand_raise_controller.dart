import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../models/hand_raise_model.dart';

/// Controller managing hand raises in a LiveKit room
/// Handles raising/lowering hands and receives updates via data packets
class HandRaiseController extends ChangeNotifier {
  HandRaiseController({required this.room}) {
    _listener = room.createListener();
    _listener.on<DataReceivedEvent>(_handleDataReceived);
  }

  final Room room;
  late final EventsListener<RoomEvent> _listener;

  /// Get sorted list of raised hands for this room
  List<RaisedHand> get raisedHands =>
      List.unmodifiable(RoomHandRaiseStore.getRaisedHands(room.name ?? ''));

  /// Check if the local participant has their hand raised
  bool get isLocalHandRaised {
    final identity = room.localParticipant?.identity;
    if (identity == null) return false;
    return raisedHands.any((h) => h.identity == identity);
  }

  /// Toggle hand raise for the local participant
  Future<void> toggleHandRaise() async {
    final local = room.localParticipant;
    if (local == null) return;

    final willRaise = !isLocalHandRaised;
    final now = DateTime.now().millisecondsSinceEpoch;

    final payload = {
      'type': willRaise ? 'hand-raised' : 'hand-lowered',
      'identity': local.identity,
      'name': local.name.isNotEmpty ? local.name : local.identity,
      'timestamp': now,
    };

    try {
      final bytes = utf8.encode(jsonEncode(payload));
      await local.publishData(
        bytes,
        topic: kHandRaiseTopic,
      );
    } catch (e) {
      debugPrint('❌ Failed to toggle hand raise: $e');
      rethrow;
    }

    _applyUpdate(
      identity: local.identity,
      name: local.name.isNotEmpty ? local.name : local.identity,
      raised: willRaise,
      timestamp: now,
    );
  }

  /// Lower hand for a specific participant (called by self)
  Future<void> lowerHandForParticipant(String identity) async {
    final name = room.remoteParticipants[identity]?.name ?? identity;

    final payload = {
      'type': 'hand-lowered',
      'identity': identity,
      'name': name,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      final bytes = utf8.encode(jsonEncode(payload));
      await room.localParticipant?.publishData(
        bytes,
        topic: kHandRaiseTopic,
      );
    } catch (e) {
      debugPrint('❌ Failed to lower hand for $identity: $e');
      rethrow;
    }

    _applyUpdate(identity: identity, name: name, raised: false, timestamp: 0);
  }

  /// Handle incoming hand raise/lower events from other participants
  void _handleDataReceived(DataReceivedEvent event) {
    if (event.topic != kHandRaiseTopic) return;

    try {
      final json = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
      final type = json['type'] as String?;
      if (type != 'hand-raised' && type != 'hand-lowered') return;

      _applyUpdate(
        identity: json['identity'] as String,
        name: json['name'] as String? ?? 'Someone',
        raised: type == 'hand-raised',
        timestamp: json['timestamp'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('❌ Failed to parse incoming hand-raise event: $e');
    }
  }

  /// Apply a hand raise/lower update to the store and notify listeners
  void _applyUpdate({
    required String identity,
    required String name,
    required bool raised,
    required int timestamp,
  }) {
    if (raised) {
      RoomHandRaiseStore.upsert(
        room.name ?? '',
        RaisedHand(identity: identity, name: name, timestamp: timestamp),
      );
    } else {
      RoomHandRaiseStore.remove(room.name ?? '', identity);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }
}
