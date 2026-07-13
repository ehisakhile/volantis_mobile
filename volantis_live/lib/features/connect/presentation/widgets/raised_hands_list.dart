import 'package:flutter/material.dart';
import '../connect_colors.dart';
import 'hand_raise_scope.dart';

/// Widget displaying list of participants with raised hands
/// Shows as a collapsible pill with count, expands to show full list
class RaisedHandsList extends StatefulWidget {
  const RaisedHandsList({
    super.key,
    this.title = 'Raised hands',
    this.showTitle = true,
  });

  final String title;
  final bool showTitle;

  @override
  State<RaisedHandsList> createState() => _RaisedHandsListState();
}

class _RaisedHandsListState extends State<RaisedHandsList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final controller = HandRaiseScope.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hands = controller.raisedHands;

        // Hide entirely when list is empty
        if (hands.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Collapsed pill view
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ConnectColors.border.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ConnectColors.border.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '✋',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${hands.length}',
                      style: TextStyle(
                        color: ConnectColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: ConnectColors.textSecondary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded list view
            if (_expanded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: ConnectColors.border.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ConnectColors.border.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: hands.asMap().entries.map((entry) {
                      final index = entry.key;
                      final hand = entry.value;
                      final isSelf = hand.identity ==
                          controller.room.localParticipant?.identity;

                      return Column(
                        children: [
                          if (index > 0)
                            Divider(
                              height: 1,
                              color: ConnectColors.border.withValues(alpha: 0.2),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                    color: ConnectColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    hand.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: ConnectColors.text,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isSelf)
                                  GestureDetector(
                                    onTap: () => controller
                                        .lowerHandForParticipant(hand.identity),
                                    child: Text(
                                      'Lower',
                                      style: TextStyle(
                                        color: ConnectColors.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
