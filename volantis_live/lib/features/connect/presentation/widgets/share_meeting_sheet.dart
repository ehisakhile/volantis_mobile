import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../connect_colors.dart';

class ShareMeetingSheet extends StatefulWidget {
  final String meetingCode;
  final String? meetingTitle;
  final VoidCallback onJoin;

  const ShareMeetingSheet({
    super.key,
    required this.meetingCode,
    this.meetingTitle,
    required this.onJoin,
  });

  @override
  State<ShareMeetingSheet> createState() => _ShareMeetingSheetState();
}

class _ShareMeetingSheetState extends State<ShareMeetingSheet> {
  String get meetingLink => 'connect.volantislive.com/${widget.meetingCode}';

  String get shareText {
    final title = widget.meetingTitle != null && widget.meetingTitle!.isNotEmpty
        ? 'Join my meeting: ${widget.meetingTitle}\n\n'
        : '';
    return '${title}Join my meeting: $meetingLink';
  }

  Future<void> _share() async {
    await Share.share(
      shareText,
      subject: widget.meetingTitle ?? 'Join my meeting',
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: meetingLink));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Link copied to clipboard'),
          backgroundColor: ConnectColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConnectColors.bg,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meeting Created',
                style: TextStyle(
                  color: ConnectColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.close,
                  color: ConnectColors.textSecondary,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.meetingTitle != null && widget.meetingTitle!.isNotEmpty) ...[
            Text(
              widget.meetingTitle!,
              style: TextStyle(
                color: ConnectColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Share this link with others to invite them to your meeting',
            style: TextStyle(
              color: ConnectColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ConnectColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ConnectColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meeting Code',
                  style: TextStyle(
                    color: ConnectColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.meetingCode,
                        style: TextStyle(
                          color: ConnectColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.meetingCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Code copied'),
                            backgroundColor: ConnectColors.success,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.copy_rounded,
                        color: ConnectColors.textTertiary,
                        size: 20,
                      ),
                      tooltip: 'Copy code',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  meetingLink,
                  style: TextStyle(
                    color: ConnectColors.accent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy Link'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ConnectColors.text,
                    side: BorderSide(color: ConnectColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ConnectColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onJoin();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ConnectColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_call_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Join Meeting',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}