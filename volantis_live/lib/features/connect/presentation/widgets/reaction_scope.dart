import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart';
import '../controllers/reaction_controller.dart';

/// Provider widget for reactions
/// Wraps a ReactionController in an InheritedNotifier, making it available to all descendants
class ReactionScope extends StatefulWidget {
  const ReactionScope({
    super.key,
    required this.room,
    required this.child,
  });

  final Room room;
  final Widget child;

  /// Get the ReactionController from the nearest ReactionScope ancestor
  static ReactionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ReactionInherited>();
    assert(scope != null, 'No ReactionScope found in context');
    return scope!.controller;
  }

  @override
  State<ReactionScope> createState() => _ReactionScopeState();
}

class _ReactionScopeState extends State<ReactionScope> {
  late final ReactionController _controller =
      ReactionController(room: widget.room);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ReactionInherited(controller: _controller, child: widget.child);
  }
}

/// InheritedNotifier widget that holds the ReactionController
class _ReactionInherited extends InheritedNotifier<ReactionController> {
  const _ReactionInherited({
    required ReactionController controller,
    required super.child,
  }) : super(notifier: controller);

  ReactionController get controller => notifier!;
}
