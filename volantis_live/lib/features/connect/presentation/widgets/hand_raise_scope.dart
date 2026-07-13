import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart';
import '../controllers/hand_raise_controller.dart';

/// Provider widget for hand raises
/// Wraps a HandRaiseController in an InheritedNotifier, making it available to all descendants
class HandRaiseScope extends StatefulWidget {
  const HandRaiseScope({
    super.key,
    required this.room,
    required this.child,
  });

  final Room room;
  final Widget child;

  /// Get the HandRaiseController from the nearest HandRaiseScope ancestor
  static HandRaiseController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_HandRaiseInherited>();
    assert(scope != null, 'No HandRaiseScope found in context');
    return scope!.controller;
  }

  @override
  State<HandRaiseScope> createState() => _HandRaiseScopeState();
}

class _HandRaiseScopeState extends State<HandRaiseScope> {
  late final HandRaiseController _controller =
      HandRaiseController(room: widget.room);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _HandRaiseInherited(controller: _controller, child: widget.child);
  }
}

/// InheritedNotifier widget that holds the HandRaiseController
class _HandRaiseInherited extends InheritedNotifier<HandRaiseController> {
  const _HandRaiseInherited({
    required HandRaiseController controller,
    required super.child,
  }) : super(notifier: controller);

  HandRaiseController get controller => notifier!;
}
