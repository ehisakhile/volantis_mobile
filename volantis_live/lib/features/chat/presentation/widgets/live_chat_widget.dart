import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/repositories/chat_repository.dart';

class LiveChatWidget extends StatefulWidget {
  final String slug;
  final bool isCreator;
  final String? companyName;

  const LiveChatWidget({
    super.key,
    required this.slug,
    this.isCreator = false,
    this.companyName,
  });

  @override
  State<LiveChatWidget> createState() => _LiveChatWidgetState();
}

class _LiveChatWidgetState extends State<LiveChatWidget> {
  final ChatRepository _repository = ChatRepository();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  ChatMessageModel? _replyTo;
  bool _isAtBottom = true;
  int _unreadCount = 0;
  int _maxId = 0;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchMessages(initial: true);
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchMessages(initial: false);
    });
  }

  void _onScroll() {
    final position = _scrollController.position;
    final atBottom = position.maxScrollExtent - position.pixels < 80;
    if (atBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottom;
        if (atBottom) _unreadCount = 0;
      });
    }
  }

  Future<void> _fetchMessages({bool initial = false}) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      if (initial) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final data = await _repository.getMessages(widget.slug, page: 1, size: 50);

      if (!mounted) return;

      if (initial) {
        setState(() {
          _messages = data;
          _isLoading = false;
          if (data.isNotEmpty) {
            _maxId = data.map((m) => m.id).reduce(math.max);
          }
        });
      } else {
        final newMessages = data.where((m) => m.id > _maxId).toList();
        if (newMessages.isNotEmpty) {
          setState(() {
            _maxId = newMessages.map((m) => m.id).reduce(math.max);
            _messages = [..._messages, ...newMessages];
            if (!_isAtBottom) {
              _unreadCount += newMessages.length;
            }
          });
        }
      }
      setState(() => _error = null);
    } catch (e) {
      if (initial) {
        setState(() {
          _error = 'Failed to load chat';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final trimmed = _messageController.text.trim();
    if (trimmed.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) return;

    String content = trimmed;
    if (_replyTo != null) {
      final prefix = _replyTo!.isCreator
          ? '@${widget.companyName ?? 'Host'}\u200B '
          : '@${_replyTo!.username}\u200B ';
      content = prefix + trimmed;
    }

    setState(() => _isSending = true);

    try {
      final message = await _repository.sendMessage(widget.slug, content);
      if (message != null && mounted) {
        setState(() {
          _messages = [..._messages, message];
          _maxId = math.max(_maxId, message.id);
          _messageController.clear();
          _replyTo = null;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to send message');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _deleteMessage(int id) async {
    final success = await _repository.deleteMessage(id);
    if (success && mounted) {
      setState(() {
        _messages = _messages.where((m) => m.id != id).toList();
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isAuthenticated) {
          return _buildUnauthenticated();
        }
        return _buildAuthenticated(authProvider);
      },
    );
  }

  Widget _buildUnauthenticated() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.login,
                    color: Colors.grey[500],
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Join the conversation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to chat with the stream',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
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

  Widget _buildAuthenticated(AuthProvider authProvider) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Stack(
              children: [
                _buildMessageList(),
                if (!_isAtBottom && _unreadCount > 0)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _buildScrollToBottomButton(),
                  ),
              ],
            ),
          ),
          if (_error != null) _buildErrorBanner(),
          if (_replyTo != null) _buildReplyBanner(),
          _buildInput(authProvider),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                color: Color(0xFF38BDF8),
                size: 16,
              ),
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34D399),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Text(
            'Live Chat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '${_messages.length}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading && _messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF38BDF8),
          strokeWidth: 2,
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              color: Colors.grey[700],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No messages yet',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to say something!',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _ChatMessageItem(
          message: message,
          isCreator: widget.isCreator,
          companyName: widget.companyName,
          currentUsername: context.read<AuthProvider>().user?.username,
          onReply: (msg) {
            setState(() => _replyTo = msg);
            _focusNode.requestFocus();
          },
          onDelete: widget.isCreator ? (id) => _deleteMessage(id) : null,
        );
      },
    );
  }

  Widget _buildScrollToBottomButton() {
    return GestureDetector(
      onTap: () {
        _scrollToBottom();
        setState(() {
          _unreadCount = 0;
          _isAtBottom = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF38BDF8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withOpacity(0.3),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            const Text(
              'New messages',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: const Icon(Icons.close, color: Colors.red, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF38BDF8).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, color: Color(0xFF38BDF8), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: _replyTo!.isCreator
                        ? (widget.companyName ?? 'Host')
                        : '@${_replyTo!.username} ',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: _replyTo!.content,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyTo = null),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                color: Colors.grey[500],
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(AuthProvider authProvider) {
    final placeholder = _replyTo != null
        ? 'Reply to ${_replyTo!.isCreator ? (widget.companyName ?? 'Host') : '@${_replyTo!.username}'}…'
        : 'Send a message…';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLength: 500,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF1E293B).withOpacity(0.6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                ),
                counterText: '',
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _messageController.text.trim().isEmpty || _isSending
                ? null
                : _sendMessage,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _messageController.text.trim().isEmpty || _isSending
                    ? const Color(0xFF38BDF8).withOpacity(0.4)
                    : const Color(0xFF38BDF8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageItem extends StatelessWidget {
  final ChatMessageModel message;
  final bool isCreator;
  final String? companyName;
  final String? currentUsername;
  final Function(ChatMessageModel) onReply;
  final Function(int)? onDelete;

  const _ChatMessageItem({
    required this.message,
    required this.isCreator,
    this.companyName,
    this.currentUsername,
    required this.onReply,
    this.onDelete,
  });

  List<Color> _getUserColors(String username) {
    final colors = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      [const Color(0xFFEC4899), const Color(0xFFF43F5E)],
      [const Color(0xFF14B8A6), const Color(0xFF22D3EE)],
      [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
      [const Color(0xFF10B981), const Color(0xFF34D399)],
      [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
      [const Color(0xFFF97316), const Color(0xFFFB923C)],
      [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
    ];
    final hash = username.hashCode.abs();
    return colors[hash % colors.length];
  }

  Color _getTextColor(String username) {
    final colors = [
      const Color(0xFFA5B4FC),
      const Color(0xFFF9A8D4),
      const Color(0xFF5EEAD4),
      const Color(0xFFFCD34D),
      const Color(0xFF6EE7B7),
      const Color(0xFF93C5FD),
      const Color(0xFFFED7AA),
      const Color(0xFFC4B5FD),
    ];
    final hash = username.hashCode.abs();
    return colors[hash % colors.length];
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final userColors = _getUserColors(message.username);
    final textColor = _getTextColor(message.username);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(userColors),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    message.isCreator
                        ? Row(
                            children: [
                              Text(
                                companyName ?? 'Creator',
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF38BDF8).withOpacity(0.3),
                                  ),
                                ),
                                child: const Text(
                                  'HOST',
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            message.username,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message.isDeleted ? 'Message removed' : message.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: message.isDeleted
                        ? Colors.grey[600]
                        : message.isCreator
                            ? Colors.grey[100]
                            : Colors.grey[300],
                    fontStyle:
                        message.isDeleted ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (!message.isDeleted)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 16),
              padding: EdgeInsets.zero,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'reply',
                  child: Row(
                    children: [
                      Icon(Icons.reply, size: 16),
                      SizedBox(width: 8),
                      Text('Reply'),
                    ],
                  ),
                ),
                if (isCreator && onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
              onSelected: (value) {
                if (value == 'reply') {
                  onReply(message);
                } else if (value == 'delete') {
                  onDelete?.call(message.id);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(List<Color> colors) {
    if (message.isCreator) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF38BDF8), Color(0xFF8B5CF6)],
          ),
          border: Border.all(
            color: const Color(0xFF38BDF8).withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withOpacity(0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Text(
            (companyName ?? 'C').substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
        ),
      ),
      child: Center(
        child: Text(
          message.username.isNotEmpty
              ? message.username.substring(0, 1).toUpperCase()
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
