import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:volantis_live/features/auth/presentation/screens/login_screen.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';
// Import shared auth design system from login_screen.dart or a shared file:
// import 'login_screen.dart'; // AuthColors, AuthGlassCard, AuthPrimaryButton, etc.

/// OTP verification screen — VolantisLive dark glass design
class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({super.key});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _digitControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  String get _otp => _digitControllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otp.length == 6) _verifyOtp();
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _digitControllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyEmail(_otp);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified successfully!'),
          backgroundColor: Color(0xFF1B5E20),
        ),
      );
      context.go('/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Invalid OTP'),
          backgroundColor: const Color(0xFF93000A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.bg,
      body: Stack(
        children: [
          // Ambient glows
          Positioned(
            top: 80,
            right: -60,
            child: _GlowBlob(
              color: AuthColors.primary.withOpacity(0.07),
              size: 240,
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: _GlowBlob(
              color: AuthColors.secondary.withOpacity(0.05),
              size: 180,
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    AuthTopBar(onBack: () => context.go('/register')),
                    const SizedBox(height: 36),

                    // Headline
                    const Text(
                      'Verify\nYour Email',
                      style: TextStyle(
                        color: AuthColors.onSurface,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.8,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the 6-digit code sent to your email.',
                      style: TextStyle(
                        color: AuthColors.onVariant,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Glass card
                    AuthGlassCard(
                      glowColor: AuthColors.primary,
                      glowAlignment: Alignment.topRight,
                      child: Column(
                        children: [
                          // Icon badge
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AuthColors.primary,
                                  AuthColors.primaryCont,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.mark_email_read_rounded,
                              color: Color(0xFF001E2F),
                              size: 36,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // 6-digit OTP boxes
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(6, (i) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: _OtpBox(
                                    controller: _digitControllers[i],
                                    focusNode: _focusNodes[i],
                                    onChanged: (v) => _onDigitChanged(i, v),
                                    onKey: (e) => _onKeyDown(i, e),
                                  ),
                                );
                              }),
                            ),
                          ),

                          const SizedBox(height: 32),

                          Consumer<AuthProvider>(
                            builder: (_, auth, __) => AuthPrimaryButton(
                              label: 'Verify Email',
                              isLoading: auth.isLoading,
                              onTap: _verifyOtp,
                              useGradient: true,
                            ),
                          ),

                          const SizedBox(height: 24),
                          const AuthDivider(label: "Didn't receive it?"),
                          const SizedBox(height: 20),

                          Center(
                            child: GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('OTP resent to your email'),
                                    backgroundColor: Color(0xFF1B5E20),
                                  ),
                                );
                              },
                              child: const Text(
                                'Resend Code',
                                style: TextStyle(
                                  color: AuthColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    const AuthFeatureCard(
                      icon: Icons.shield_rounded,
                      iconBg: Color(0xFF003751),
                      iconColor: AuthColors.primary,
                      title: 'Check Your Inbox',
                      subtitle:
                          "The code expires in 10 minutes. Check spam if you don't see it.",
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── OTP digit box ─────────────────────────────────────────────────────────────

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<RawKeyEvent> onKey;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: onKey,
      child: SizedBox(
        width: 44,
        height: 56,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          style: const TextStyle(
            color: AuthColors.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AuthColors.surfaceHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AuthColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

// ── Glow blob (local) ─────────────────────────────────────────────────────────

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
