import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../connect_colors.dart';
import 'chat_panel.dart';

/// Menu dialog for additional call options (camera flip, chat, reactions)
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
      child: DefaultTabController(
        length: 2, // Camera options and Chat
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with tabs
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: ConnectColors.border,
                  ),
                ),
              ),
              child: TabBar(
                indicatorColor: ConnectColors.accent,
                labelColor: ConnectColors.text,
                unselectedLabelColor: ConnectColors.textSecondary,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flip_camera_ios_rounded, size: 18),
                        const SizedBox(width: 8),
                        const Text('Camera'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_rounded, size: 18),
                        const SizedBox(width: 8),
                        const Text('Chat'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab content
            SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.6,
              child: TabBarView(
                children: [
                  // Camera options tab
                  _CameraOptionsTab(
                    onFlipCamera: onFlipCamera,
                    onClose: () => Navigator.pop(ctx),
                  ),

                  // Chat tab
                  ChatPanel(room: room),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Camera options tab content
class _CameraOptionsTab extends StatelessWidget {
  final VoidCallback onFlipCamera;
  final VoidCallback onClose;

  const _CameraOptionsTab({
    required this.onFlipCamera,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Camera Options',
                style: TextStyle(
                  color: ConnectColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Flip camera option
              _OptionTile(
                icon: Icons.flip_camera_ios_rounded,
                title: 'Flip Camera',
                subtitle: 'Switch between front and back camera',
                onTap: () {
                  onFlipCamera();
                  onClose();
                },
              ),

              const SizedBox(height: 12),

              // Placeholder for more camera options
              _OptionTile(
                icon: Icons.settings_rounded,
                title: 'Camera Settings',
                subtitle: 'Adjust camera resolution and more',
                onTap: () {
                  // TODO: Add camera settings
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Reusable option tile for menu items
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ConnectColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: ConnectColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: ConnectColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: ConnectColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: ConnectColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
