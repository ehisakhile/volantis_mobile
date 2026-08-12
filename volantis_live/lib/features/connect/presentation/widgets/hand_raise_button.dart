import 'package:flutter/material.dart';
import '../connect_colors.dart';
import 'hand_raise_scope.dart';

/// Button for raising/lowering hand
/// Shows visual indication when hand is raised
class HandRaiseButton extends StatefulWidget {
  const HandRaiseButton({super.key});

  @override
  State<HandRaiseButton> createState() => _HandRaiseButtonState();
}

class _HandRaiseButtonState extends State<HandRaiseButton> {
  bool _isLoading = false;

  Future<void> _handleTap() async {
    setState(() => _isLoading = true);
    try {
      await HandRaiseScope.of(context).toggleHandRaise();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update hand raise')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = HandRaiseScope.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final raised = controller.isLocalHandRaised;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _handleTap,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: raised
                    ? Colors.blue.shade500
                    : ConnectColors.border.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: raised
                      ? Colors.blue.shade600
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          raised ? Colors.white : ConnectColors.text,
                        ),
                      ),
                    )
                  else
                    Text(
                      '✋',
                      style: TextStyle(fontSize: raised ? 16 : 14),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    raised ? 'Hand raised' : 'Raise hand',
                    style: TextStyle(
                      color: raised ? Colors.white : ConnectColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
