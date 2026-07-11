import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../connect_colors.dart';
import '../providers/meeting_provider.dart';
import '../widgets/prejoin_sheet.dart';
import '../../data/meeting_code_parser.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Connect tab main screen for creating and joining meetings
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _joinCodeController = TextEditingController();
  bool _isCreatingMeeting = false;
  bool _isJoiningMeeting = false;
  String? _joinError;

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

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
      print('ConnectScreen: Created meeting ${meeting.niceId}');

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
      print('ConnectScreen: Error creating meeting: $e');
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
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _joinError = null);

    final meetingProvider = context.read<MeetingProvider>();
    final authProvider = context.read<AuthProvider>();

    setState(() => _isJoiningMeeting = true);

    try {
      // Check if user is authenticated
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
      print('ConnectScreen: Error joining meeting: $e');
      setState(() {
        _joinError = e.toString();
        _isJoiningMeeting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          ? SizedBox(
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Join Code Field
              TextField(
                controller: _joinCodeController,
                onSubmitted: _isJoiningMeeting ? null : (_) => _joinMeeting(),
                enabled: !_isJoiningMeeting,
                style: TextStyle(color: ConnectColors.text, fontSize: 15),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: ConnectColors.bgCard,
                  hintText: 'Enter meeting code or link',
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
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: ConnectColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: ConnectColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: ConnectColors.accent,
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
                Text(
                  _joinError!,
                  style: TextStyle(color: ConnectColors.error, fontSize: 12),
                ),
              ],

              const SizedBox(height: 16),

              // Join Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed:
                      _isJoiningMeeting || _joinCodeController.text.isEmpty
                      ? null
                      : _joinMeeting,
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
                    side: BorderSide(
                      color: ConnectColors.accent.withValues(alpha: 0.5),
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
                      'Create a meeting or join with a code. Invite others to join using the generated code. '
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
