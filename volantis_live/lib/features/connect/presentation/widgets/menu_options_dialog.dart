import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../connect_colors.dart';
import 'chat_panel.dart';

/// Menu dialog for additional call options (chat only)
void showMenuOptionsDialog(
  BuildContext context, {
  required VoidCallback onFlipCamera,
  required Room room,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: ConnectColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with title
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: ConnectColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_rounded,
                    color: ConnectColors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Chat',
                    style: TextStyle(
                      color: ConnectColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Chat content
            SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.6,
              child: ChatPanel(room: room),
            ),
          ],
        ),
      ),
    ),
  );
}
