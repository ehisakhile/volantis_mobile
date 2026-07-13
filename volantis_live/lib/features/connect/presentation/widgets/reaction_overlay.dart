import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/reaction_instance.dart';
import 'reaction_scope.dart';

/// Full-screen overlay that displays animated floating reactions
/// Non-interactive (IgnorePointer), allows reactions to float behind the UI
class ReactionOverlay extends StatelessWidget {
  const ReactionOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ReactionScope.of(context);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Stack(
            children: controller.activeReactions
                .map((r) => _FloatingReaction(
                      key: ValueKey(r.id),
                      reaction: r,
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

/// Single animated reaction emoji
/// Floats up, scales, rotates, and fades out over 2.5-4 seconds
class _FloatingReaction extends StatelessWidget {
  const _FloatingReaction({
    super.key,
    required this.reaction,
  });

  final ReactionInstance reaction;

  @override
  Widget build(BuildContext context) {
    // Use reaction ID as seed for deterministic randomness
    final random = Random(reaction.id.hashCode);

    // Horizontal position: 10%-90% of screen width
    final leftPercent = 0.10 + random.nextDouble() * 0.80;

    // Horizontal drift as it rises: -40 to 40 pixels
    final drift = (random.nextDouble() * 80) - 40;

    // Rotation: -20 to 20 degrees
    final rotation = (random.nextDouble() * 40) - 20;

    // Scale: 0.9 to 1.2
    final scale = 0.9 + random.nextDouble() * 0.3;

    // Duration: 2.5 to 4 seconds
    final durationMs = 2500 + random.nextInt(1500);

    final size = MediaQuery.of(context).size;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        // Rise 85% of screen height
        final riseY = size.height * 0.85 * t;

        // Fade in for first 10%, then fade out after 50% progress
        final opacity = t < 0.1
            ? t / 0.1
            : (1 - ((t - 0.5) / 0.5)).clamp(0.0, 1.0);

        return Positioned(
          left: size.width * leftPercent + (drift * t),
          bottom: riseY,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: rotation * pi / 180,
              child: Transform.scale(
                scale: scale,
                child: Text(
                  reaction.emoji,
                  style: const TextStyle(fontSize: 36),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
