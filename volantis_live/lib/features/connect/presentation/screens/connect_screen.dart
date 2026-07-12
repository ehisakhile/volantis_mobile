import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../connect_colors.dart';
import '../providers/meeting_provider.dart';
import '../widgets/prejoin_sheet.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Connect tab main screen for creating and joining meetings
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _joinCodeController = TextEditingController();
  final _joinFocusNode = FocusNode();

  bool _isCreatingMeeting = false;
  bool _isJoiningMeeting = false;
  String? _joinError;

  @override
  void initState() {
    super.initState();
    // Rebuild on every keystroke so the Join button + parsed-code preview
    // stay in sync with what's typed/pasted.
    _joinCodeController.addListener(_onJoinTextChanged);
  }

  void _onJoinTextChanged() {
    if (_joinError != null) {
      setState(() => _joinError = null);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _joinCodeController.removeListener(_onJoinTextChanged);
    _joinCodeController.dispose();
    _joinFocusNode.dispose();
    super.dispose();
  }

  /// Extracts a clean meeting code from whatever the user typed or pasted.
  ///
  /// Handles:
  ///  - Full links, e.g. https://connect.volantislive.com/btzm8pnjedsy
  ///  - Links with trailing slashes, query params, or fragments
  ///  - Links without a scheme, e.g. connect.volantislive.com/btzm8pnjedsy
  ///  - Raw codes with stray whitespace, dashes, or mixed case
  ///
  /// Returns null if no plausible code could be found.
  static String? extractMeetingCode(String raw) {
    var input = raw.trim();
    if (input.isEmpty) return null;

    // If it looks like a link (has a scheme or a dot-separated host followed
    // by a path), pull the last non-empty path segment.
    final looksLikeUrl =
        input.contains('/') &&
        (input.startsWith('http://') ||
            input.startsWith('https://') ||
            RegExp(r'^[\w-]+(\.[\w-]+)+/').hasMatch(input));

    if (looksLikeUrl) {
      final normalized =
          input.startsWith('http://') || input.startsWith('https://')
          ? input
          : 'https://$input';

      final uri = Uri.tryParse(normalized);
      final segments = uri?.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments != null && segments.isNotEmpty) {
        input = segments.last;
      }
    }

    // Strip anything that isn't alphanumeric (handles stray dashes, spaces
    // pasted in the middle of a code, etc.) and normalize case.
    final code = input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

    if (code.length < 4) return null;
    return code;
  }

  String? get _parsedCode => extractMeetingCode(_joinCodeController.text);

  Future<void> _createMeeting() async {
    final authProvider = context.read<AuthProvider>();
    final meetingProvider = context.read<MeetingProvider>();

    if (!authProvider.isAuthenticated) {
      context.push('/login');
      return;
    }

    setState(() => _isCreatingMeeting = true);

    try {
      final meeting = await meetingProvider.createInstantMeeting();

      if (!mounted) return;

      // Show prejoin sheet
      final settings = await showModalBottomSheet<PrejoinSettings>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const PrejoinSheet(isGuest: false),
      );

      if (settings == null) {
        setState(() => _isCreatingMeeting = false);
        return;
      }

      if (!mounted) return;

      // Now we have user's preference - navigate to room
      context.push(
        '/connect/room/${meeting.niceId}',
        extra: MeetingJoinArgs(
          token: meeting.livekit?.token ?? '',
          url: meeting.livekit?.livekitUrl ?? '',
          room: meeting.livekit?.room ?? '',
          displayName: authProvider.user?.username ?? 'User',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingMeeting = false);
      }
    }
  }

  Future<void> _joinMeeting() async {
    final code = extractMeetingCode(_joinCodeController.text);

    if (code == null) {
      setState(
        () =>
            _joinError = "That doesn't look like a valid meeting code or link",
      );
      return;
    }

    setState(() {
      _joinError = null;
      _isJoiningMeeting = true;
    });
    _joinFocusNode.unfocus();

    final meetingProvider = context.read<MeetingProvider>();
    final authProvider = context.read<AuthProvider>();

    try {
      if (authProvider.isAuthenticated) {
        // Authenticated join
        final args = await meetingProvider.resolveJoin(code);
        if (!mounted) return;
        context.push('/connect/room/$code', extra: args);
      } else {
        // Guest join - show prejoin sheet with name field
        final settings = await showModalBottomSheet<PrejoinSettings>(
          context: context,
          isScrollControlled: true,
          builder: (context) => const PrejoinSheet(isGuest: true),
        );

        if (settings == null || settings.guestName == null) {
          setState(() => _isJoiningMeeting = false);
          return;
        }

        if (!mounted) return;

        // Resolve join with guest name
        final args = await meetingProvider.resolveJoin(
          code,
          guestName: settings.guestName,
        );

        if (!mounted) return;

        context.push('/connect/room/$code', extra: args);
      }
    } catch (e) {
      setState(() {
        _joinError =
            'Could not join that meeting. Double-check the code and try again.';
        _isJoiningMeeting = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isJoiningMeeting = false);
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;

    _joinCodeController.text = text.trim();
    _joinCodeController.selection = TextSelection.collapsed(
      offset: _joinCodeController.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _joinCodeController.text.trim().isNotEmpty;
    final parsedCode = _parsedCode;
    final canJoin =
        !_isJoiningMeeting && !_isCreatingMeeting && parsedCode != null;

    return Scaffold(
      backgroundColor: ConnectColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Connect',
                style: TextStyle(
                  color: ConnectColors.text,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 60,
                height: 3,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFFA78BFA)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                'Start or join a private audio and video room.',
                style: TextStyle(
                  color: ConnectColors.textTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 28),

              // Create Room Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    return ElevatedButton.icon(
                      onPressed: _isCreatingMeeting || _isJoiningMeeting
                          ? null
                          : _createMeeting,
                      icon: _isCreatingMeeting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.video_call_rounded, size: 22),
                      label: Text(
                        authProvider.isAuthenticated
                            ? 'New Meeting'
                            : 'Sign In to Create',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(child: Divider(color: ConnectColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR JOIN A MEETING',
                      style: TextStyle(
                        color: ConnectColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: ConnectColors.border)),
                ],
              ),

              const SizedBox(height: 16),

              // Join Code Field
              TextField(
                controller: _joinCodeController,
                focusNode: _joinFocusNode,
                onSubmitted: canJoin ? (_) => _joinMeeting() : null,
                enabled: !_isJoiningMeeting,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                autocorrect: false,
                style: TextStyle(color: ConnectColors.text, fontSize: 15),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: ConnectColors.bgCard,
                  hintText: 'Paste a link or enter a meeting code',
                  hintStyle: TextStyle(color: ConnectColors.textTertiary),
                  prefixIcon: Icon(
                    Icons.link_rounded,
                    color: ConnectColors.accent,
                    size: 22,
                  ),
                  suffixIcon: _isJoiningMeeting
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ConnectColors.accent,
                              ),
                            ),
                          ),
                        )
                      : hasText
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: ConnectColors.textTertiary,
                            size: 20,
                          ),
                          onPressed: () {
                            _joinCodeController.clear();
                            setState(() => _joinError = null);
                          },
                        )
                      : IconButton(
                          icon: Icon(
                            Icons.content_paste_rounded,
                            color: ConnectColors.textTertiary,
                            size: 20,
                          ),
                          tooltip: 'Paste',
                          onPressed: _pasteFromClipboard,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: ConnectColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _joinError != null
                          ? ConnectColors.error
                          : ConnectColors.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _joinError != null
                          ? ConnectColors.error
                          : ConnectColors.accent,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),

              // Join error message
              if (_joinError != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: ConnectColors.error,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _joinError!,
                        style: TextStyle(
                          color: ConnectColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ]
              // Live preview of the parsed code so people know what they'll
              // actually join, e.g. when they paste a full link.
              else if (hasText && parsedCode != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: ConnectColors.accent,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Joining code: $parsedCode',
                      style: TextStyle(
                        color: ConnectColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Join Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: canJoin ? _joinMeeting : null,
                  icon: const Icon(Icons.input_rounded, size: 20),
                  label: const Text(
                    'Join Meeting',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ConnectColors.accent,
                    disabledForegroundColor: ConnectColors.textTertiary
                        .withValues(alpha: 0.6),
                    side: BorderSide(
                      color: canJoin
                          ? ConnectColors.accent.withValues(alpha: 0.5)
                          : ConnectColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ConnectColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ConnectColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: ConnectColors.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: TextStyle(
                            color: ConnectColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a meeting or join with a code. Invite others by sharing the '
                      'generated link, e.g. connect.volantislive.com/btzm8pnjedsy — pasting '
                      'the full link or just the code both work. '
                      'You can enable or disable your camera and microphone at any time.',
                      style: TextStyle(
                        color: ConnectColors.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
