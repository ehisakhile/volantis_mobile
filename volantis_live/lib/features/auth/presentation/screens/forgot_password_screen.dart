import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import '../providers/auth_provider.dart';

/// Forgot Password screen — VolantisLive dark glass design
/// Supports two-step flow:
/// 1. Request password reset (enter email)
/// 2. Verify OTP and set new password
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final List<TextEditingController> _digitControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isStepOne = true; // true = email entry, false = OTP verification
  String? _successMessage;

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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestPasswordReset() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.requestPasswordReset(_emailController.text.trim());

    if (!mounted) return;

    if (ok) {
      setState(() {
        _isStepOne = false;
        _successMessage = 'Password reset code sent to your email';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to send reset code'),
          backgroundColor: const Color(0xFF93000A),
        ),
      );
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otp.length == 6) {
      _focusNodes[5].unfocus();
    }
  }

  Future<void> _verifyPasswordReset() async {
    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit code'),
          backgroundColor: Color(0xFF93000A),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyPasswordReset(_otp, _passwordController.text);

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successful! Welcome back!'),
          backgroundColor: Color(0xFF1B5E20),
        ),
      );
      // Navigate to home - user is already authenticated
      final destination = auth.isCreator ? '/creator' : '/home';
      context.go(destination);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Invalid OTP or password'),
          backgroundColor: const Color(0xFF93000A),
        ),
      );
    }
  }

  void _goBack() {
    if (_isStepOne) {
      context.go('/login');
    } else {
      setState(() {
        _isStepOne = true;
        _successMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.bg,
      body: Stack(
        children: [
          // Ambient glow blobs
          Positioned(
            bottom: -80,
            left: -80,
            child: _GlowBlob(
              // ignore: deprecated_member_use
              color: AuthColors.secondary.withOpacity(0.07),
              size: 280,
            ),
          ),
          Positioned(
            top: 60,
            right: -60,
            child: _GlowBlob(
              // ignore: deprecated_member_use
              color: AuthColors.primary.withOpacity(0.06),
              size: 220,
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        AuthTopBar(onBack: _goBack),
                        const SizedBox(height: 36),

                        // Headline
                        Text(
                          _isStepOne ? 'Forgot\nPassword' : 'Reset\nPassword',
                          style: const TextStyle(
                            color: AuthColors.onSurface,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.8,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isStepOne
                              ? 'Enter your email to receive a reset code.'
                              : 'Enter the code sent to your email and create a new password.',
                          style: const TextStyle(
                            color: AuthColors.onVariant,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Glass card
                        AuthGlassCard(
                          glowColor: AuthColors.secondary,
                          glowAlignment: Alignment.bottomLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isStepOne) ...[
                                // Step 1: Email input
                                const AuthFieldLabel('Email'),
                                const SizedBox(height: 6),
                                AuthDarkInput(
                                  controller: _emailController,
                                  hint: 'name@domain.com',
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [
                                    AutofillHints.email,
                                    AutofillHints.username,
                                  ],
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Enter your email';
                                    }
                                    if (!v.contains('@')) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                  onSubmitted: (_) => _requestPasswordReset(),
                                ),

                                const SizedBox(height: 28),

                                Consumer<AuthProvider>(
                                  builder: (_, auth, __) => AuthPrimaryButton(
                                    label: 'Send Reset Code',
                                    isLoading: auth.isLoading,
                                    onTap: _requestPasswordReset,
                                    useGradient: false,
                                  ),
                                ),
                              ] else ...[
                                // Step 2: OTP and new password
                                if (_successMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF1B5E20,
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline,
                                          color: Color(0xFF4CAF50),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _successMessage!,
                                            style: const TextStyle(
                                              color: Color(0xFF4CAF50),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                const AuthFieldLabel('Verification Code'),
                                const SizedBox(height: 6),
                                _buildOtpInput(),
                                const SizedBox(height: 6),
                                const Text(
                                  'Enter the 6-digit code from your email',
                                  style: TextStyle(
                                    color: AuthColors.outline,
                                    fontSize: 11,
                                  ),
                                ),

                                const SizedBox(height: 20),

                                const AuthFieldLabel('New Password'),
                                const SizedBox(height: 6),
                                AuthDarkInput(
                                  controller: _passwordController,
                                  hint: '••••••••',
                                  obscure: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AuthColors.outlineVar,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Enter your password';
                                    }
                                    if (v.length < 6) return 'Min 6 characters';
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 20),

                                const AuthFieldLabel('Confirm Password'),
                                const SizedBox(height: 6),
                                AuthDarkInput(
                                  controller: _confirmPasswordController,
                                  hint: '••••••••',
                                  obscure: _obscureConfirmPassword,
                                  textInputAction: TextInputAction.done,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AuthColors.outlineVar,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Confirm your password';
                                    }
                                    if (v != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                  onSubmitted: (_) => _verifyPasswordReset(),
                                ),

                                const SizedBox(height: 28),

                                Consumer<AuthProvider>(
                                  builder: (_, auth, __) => AuthPrimaryButton(
                                    label: 'Reset Password',
                                    isLoading: auth.isLoading,
                                    onTap: _verifyPasswordReset,
                                    useGradient: false,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),
                              const AuthDivider(label: 'Secure Access'),
                              const SizedBox(height: 20),

                              Center(
                                child: GestureDetector(
                                  onTap: () => context.go('/login'),
                                  child: RichText(
                                    text: const TextSpan(
                                      style: TextStyle(
                                        color: AuthColors.onVariant,
                                        fontSize: 14,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'Remember your password? ',
                                        ),
                                        TextSpan(
                                          text: 'Log In',
                                          style: TextStyle(
                                            color: AuthColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        const AuthFeatureCard(
                          icon: Icons.lock_outline_rounded,
                          iconBg: Color(0xFF6001D1),
                          iconColor: Color(0xFFC9AEFF),
                          title: 'Secure Password Reset',
                          subtitle:
                              'We\'ll send a verification code to your registered email to reset your password.',
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 5 ? 6 : 0),
            child: TextFormField(
              controller: _digitControllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              style: const TextStyle(
                color: AuthColors.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AuthColors.surfaceHigh,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AuthColors.primary,
                    width: 2,
                  ),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              onChanged: (value) => _onDigitChanged(index, value),
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED AUTH DESIGN SYSTEM (re-exported from login_screen)
// ═══════════════════════════════════════════════════════════════════════════════

// Glow blob widget
class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}
