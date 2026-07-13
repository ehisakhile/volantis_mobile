import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:livekit_client/livekit_client.dart';
import '../connect_colors.dart';
import '../../models/chat_message.dart';

const String kChatTopic = 'lk.chat';

/// Simple in-memory persistence per room
class RoomChatStore {
  static final Map<String, List<LKChatMessage>> _store = {};

  static List<LKChatMessage> getMessages(String roomId) {
    return _store.putIfAbsent(roomId, () => []);
  }

  static void addMessage(String roomId, LKChatMessage msg) {
    _store.putIfAbsent(roomId, () => []).add(msg);
  }

  static void clear(String roomId) {
    _store.remove(roomId);
  }
}

/// Chat panel for real-time messaging in LiveKit rooms.
/// Uses LiveKit's text-stream chat protocol (topic "lk.chat"), which is what
/// @livekit/components-react's <Chat /> / useChat() speaks on the web side.
class ChatPanel extends StatefulWidget {
  final Room room;

  const ChatPanel({super.key, required this.room});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  bool _isLoading = false;
  bool _hasText = false;
  bool _handlerRegistered = false;

  List<LKChatMessage> get messages =>
      RoomChatStore.getMessages(widget.room.name ?? '');

  static const _avatarPalette = <Color>[
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFFE17055),
    Color(0xFF0984E3),
    Color(0xFFD63031),
    Color(0xFFE84393),
    Color(0xFF00CEC9),
  ];

  @override
  void initState() {
    super.initState();
    _setupChatHandler();
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(animate: false),
    );
  }

  /// ✅ Register a handler for incoming "lk.chat" text streams.
  /// This is what livekit-components-react's Chat component sends on
  /// (via room.localParticipant.sendText(text, { topic: 'lk.chat' })).
  void _setupChatHandler() {
    try {
      widget.room.registerTextStreamHandler(kChatTopic, (
        TextStreamReader reader,
        String participantIdentity,
      ) async {
        if (participantIdentity == widget.room.localParticipant?.identity) {
          return;
        }

        try {
          final text = await reader.readAll();

          final senderName =
              widget.room.getParticipantByIdentity(participantIdentity)?.name ??
              participantIdentity;

          final msg = LKChatMessage(
            id:
                reader.info?.id ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            senderId: participantIdentity,
            senderName: senderName.isNotEmpty
                ? senderName
                : participantIdentity,
            message: text,
            timestamp:
                reader.info?.timestamp ?? DateTime.now().millisecondsSinceEpoch,
          );

          debugPrint('📥 Received: "${msg.message}" from ${msg.senderName}');

          if (mounted) {
            setState(() {
              RoomChatStore.addMessage(widget.room.name ?? '', msg);
            });
            _scrollToBottom();
          }
        } catch (e) {
          debugPrint('❌ Failed to read chat stream: $e');
        }
      });
      _handlerRegistered = true;
    } catch (e) {
      debugPrint('❌ Failed to register chat handler: $e');
    }
  }

  /// ✅ Send message via LiveKit text stream on the "lk.chat" topic.
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final participant = widget.room.localParticipant;
    if (participant == null) {
      debugPrint('❌ No local participant');
      return;
    }

    setState(() => _isLoading = true);
    _messageController.clear();

    try {
      final info = await participant.sendText(
        text,
        options: SendTextOptions(topic: kChatTopic),
      );

      final msg = LKChatMessage(
        id: info.id,
        senderId: participant.identity,
        senderName: participant.name.isNotEmpty ? participant.name : 'User',
        message: text,
        timestamp: info.timestamp,
      );

      debugPrint('📤 Sent: $text');

      setState(() {
        RoomChatStore.addMessage(widget.room.name ?? '', msg);
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('❌ Send failed: $e');
      _messageController.text = text;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send message'),
            backgroundColor: ConnectColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(max);
      }
    });
  }

  Color _avatarColorFor(String senderId) {
    final hash = senderId.codeUnits.fold<int>(0, (a, b) => a + b);
    return _avatarPalette[hash % _avatarPalette.length];
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String _formatTime(DateTime dt) {
    final hour24 = dt.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDateSeparator(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dt.weekday - 1];
    }
    return '${_months[dt.month - 1]} ${dt.day}${dt.year != now.year ? ', ${dt.year}' : ''}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Builds a flat, chronological list of display items: date separators
  /// and messages, with grouping metadata (avatar/name visibility).
  List<_ChatDisplayItem> _buildDisplayItems() {
    final items = <_ChatDisplayItem>[];
    DateTime? lastDate;
    LKChatMessage? prevMsg;

    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final dt = DateTime.fromMillisecondsSinceEpoch(msg.timestamp);

      if (lastDate == null || !_isSameDay(lastDate, dt)) {
        items.add(_ChatDisplayItem.date(dt));
        lastDate = dt;
        prevMsg = null;
      }

      final sameSenderAsPrev =
          prevMsg != null && prevMsg.senderId == msg.senderId;
      final closeInTime =
          prevMsg != null &&
          (msg.timestamp - prevMsg.timestamp) <
              const Duration(minutes: 5).inMilliseconds;
      final showAvatarAndName = !(sameSenderAsPrev && closeInTime);

      final next = i + 1 < messages.length ? messages[i + 1] : null;
      final nextIsSameGroup =
          next != null &&
          next.senderId == msg.senderId &&
          (next.timestamp - msg.timestamp) <
              const Duration(minutes: 5).inMilliseconds;

      items.add(
        _ChatDisplayItem.message(
          message: msg,
          showAvatarAndName: showAvatarAndName,
          showTimestamp: !nextIsSameGroup,
        ),
      );

      prevMsg = msg;
    }

    return items;
  }

  @override
  void dispose() {
    if (_handlerRegistered) {
      try {
        widget.room.unregisterTextStreamHandler(kChatTopic);
      } catch (e) {
        debugPrint('❌ Failed to unregister chat handler: $e');
      }
    }
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildDisplayItems();

    return Column(
      children: [
        /// Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: ConnectColors.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Chat',
                style: TextStyle(
                  color: ConnectColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              if (messages.isNotEmpty)
                Text(
                  '${messages.length}',
                  style: TextStyle(
                    color: ConnectColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),

        /// Messages
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 40,
                        color: ConnectColors.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          color: ConnectColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Say hello 👋',
                        style: TextStyle(
                          color: ConnectColors.textSecondary.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    if (item.isDate) {
                      return _DateSeparator(
                        label: _formatDateSeparator(item.date!),
                      );
                    }

                    final msg = item.message!;
                    final isMe =
                        msg.senderId == widget.room.localParticipant?.identity;

                    return _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      showAvatarAndName: item.showAvatarAndName,
                      showTimestamp: item.showTimestamp,
                      timeLabel: _formatTime(
                        DateTime.fromMillisecondsSinceEpoch(msg.timestamp),
                      ),
                      avatarColor: _avatarColorFor(msg.senderId),
                      initials: _initialsFor(msg.senderName),
                    );
                  },
                ),
        ),

        /// Message input
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: Container(
                      decoration: BoxDecoration(
                        color: ConnectColors.border.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _inputFocusNode,
                        enabled: !_isLoading,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          color: ConnectColors.text,
                          fontSize: 14.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message',
                          hintStyle: TextStyle(
                            color: ConnectColors.textSecondary,
                            fontSize: 14.5,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: _hasText
                        ? ConnectColors.accent
                        : ConnectColors.accent.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded, size: 20),
                    color: Colors.white,
                    onPressed: (_isLoading || !_hasText) ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A single item in the flattened chat display list.
class _ChatDisplayItem {
  final DateTime? date;
  final LKChatMessage? message;
  final bool showAvatarAndName;
  final bool showTimestamp;

  _ChatDisplayItem.date(this.date)
    : message = null,
      showAvatarAndName = false,
      showTimestamp = false;

  _ChatDisplayItem.message({
    required this.message,
    required this.showAvatarAndName,
    required this.showTimestamp,
  }) : date = null;

  bool get isDate => date != null;
}

class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: ConnectColors.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(
                color: ConnectColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: ConnectColors.border, height: 1)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final LKChatMessage message;
  final bool isMe;
  final bool showAvatarAndName;
  final bool showTimestamp;
  final String timeLabel;
  final Color avatarColor;
  final String initials;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatarAndName,
    required this.showTimestamp,
    required this.timeLabel,
    required this.avatarColor,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : (showAvatarAndName ? 4 : 16)),
      bottomRight: Radius.circular(isMe ? (showAvatarAndName ? 4 : 16) : 16),
    );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: isMe
            ? ConnectColors.accent
            : ConnectColors.border.withOpacity(0.55),
        borderRadius: bubbleRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe && showAvatarAndName)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                message.senderName,
                style: TextStyle(
                  color: avatarColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          _LinkifiedText(
            text: message.message,
            baseStyle: TextStyle(
              color: isMe ? Colors.white : ConnectColors.text,
              fontSize: 14.5,
              height: 1.3,
            ),
            linkStyle: TextStyle(
              color: isMe ? Colors.white : ConnectColors.accent,
              fontSize: 14.5,
              height: 1.3,
              decoration: TextDecoration.underline,
              decorationColor: isMe ? Colors.white70 : ConnectColors.accent,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: showAvatarAndName ? 10 : 2,
        bottom: showTimestamp ? 2 : 0,
      ),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            SizedBox(
              width: 28,
              height: 28,
              child: showAvatarAndName
                  ? CircleAvatar(
                      radius: 14,
                      backgroundColor: avatarColor,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                bubble,
                if (showTimestamp)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Text(
                      timeLabel,
                      style: TextStyle(
                        color: ConnectColors.textSecondary.withOpacity(0.8),
                        fontSize: 10.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Renders text with http(s)/www links as tappable, styled spans.
class _LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle baseStyle;
  final TextStyle linkStyle;

  const _LinkifiedText({
    required this.text,
    required this.baseStyle,
    required this.linkStyle,
  });

  @override
  State<_LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<_LinkifiedText> {
  static final RegExp _urlRegex = RegExp(
    r'((https?:\/\/)|(www\.))[^\s]+[^\s.,!?;:)\]]',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _openLink(String raw) async {
    final url = raw.startsWith('www.') ? 'https://$raw' : raw;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ Could not launch $url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in _urlRegex.allMatches(widget.text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: widget.text.substring(lastEnd, match.start),
            style: widget.baseStyle,
          ),
        );
      }

      final linkText = widget.text.substring(match.start, match.end);
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _openLink(linkText);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: linkText,
          style: widget.linkStyle,
          recognizer: recognizer,
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < widget.text.length) {
      spans.add(
        TextSpan(text: widget.text.substring(lastEnd), style: widget.baseStyle),
      );
    }

    return RichText(
      text: TextSpan(children: spans, style: widget.baseStyle),
    );
  }
}
