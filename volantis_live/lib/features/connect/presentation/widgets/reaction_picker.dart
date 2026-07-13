import 'package:flutter/material.dart';
import 'reaction_scope.dart';

/// Reaction picker widget with emoji buttons
/// Users tap to send reactions in the call
class ReactionPicker extends StatefulWidget {
  const ReactionPicker({
    super.key,
    this.reactions = const ['👏', '🎉', '❤️', '😂', '👍', '🔥'],
  });

  final List<String> reactions;

  @override
  State<ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<ReactionPicker> {
  DateTime? _lastSentAt;
  bool _isLoading = false;

  Future<void> _handleTap(String emoji) async {
    final now = DateTime.now();

    // Rate limit: allow only one reaction per 200ms
    if (_lastSentAt != null &&
        now.difference(_lastSentAt!) < const Duration(milliseconds: 200)) {
      return;
    }
    _lastSentAt = now;

    setState(() => _isLoading = true);
    try {
      await ReactionScope.of(context).sendReaction(emoji);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send reaction')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: widget.reactions
          .map((emoji) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : () => _handleTap(emoji),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
