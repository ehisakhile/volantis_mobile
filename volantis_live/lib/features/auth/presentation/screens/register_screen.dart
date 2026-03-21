import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:volantis_live/features/auth/presentation/screens/login_screen.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';
// Import shared auth design system from login_screen.dart or a shared file:
// import 'login_screen.dart'; // AuthColors, AuthGlassCard, AuthDarkInput, etc.

/// Register screen — VolantisLive dark glass design
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

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
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms of Service'),
          backgroundColor: Color(0xFF93000A),
        ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.signup(
      _emailController.text.trim(),
      _usernameController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (ok) {
      context.go('/verify-otp');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? AppStrings.somethingWentWrong),
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
            top: -60,
            right: -60,
            child: _GlowBlob(
              color: AuthColors.primary.withOpacity(0.08),
              size: 260,
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: _GlowBlob(
              color: AuthColors.secondary.withOpacity(0.06),
              size: 200,
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
                        AuthTopBar(onBack: () => context.go('/login')),
                        const SizedBox(height: 36),

                        // Headline
                        const Text(
                          'Create\nAccount',
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
                          'Join the future of live audio and video.',
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AuthFieldLabel('Username'),
                              const SizedBox(height: 6),
                              AuthDarkInput(
                                controller: _usernameController,
                                hint: 'your_name',
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Enter a username';
                                  }
                                  if (v.length < 3) return 'Min 3 characters';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),
                              const AuthFieldLabel('Email'),
                              const SizedBox(height: 6),
                              AuthDarkInput(
                                controller: _emailController,
                                hint: 'youremail@gmail.com',
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
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
                              ),

                              const SizedBox(height: 20),
                              const AuthFieldLabel('Password'),
                              const SizedBox(height: 6),
                              AuthDarkInput(
                                controller: _passwordController,
                                hint: '••••••••',
                                obscure: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AuthColors.outlineVar,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Enter a password';
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
                                obscure: _obscureConfirm,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _signup(),
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AuthColors.outlineVar,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
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
                              ),

                              const SizedBox(height: 20),

                              // Terms checkbox
                              GestureDetector(
                                onTap: () => setState(
                                  () => _agreedToTerms = !_agreedToTerms,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AuthCheckBox(checked: _agreedToTerms),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: RichText(
                                        text: const TextSpan(
                                          style: TextStyle(
                                            color: AuthColors.onVariant,
                                            fontSize: 13,
                                            height: 1.5,
                                          ),
                                          children: [
                                            TextSpan(text: 'I agree to the '),
                                            TextSpan(
                                              text: 'Terms of Service',
                                              style: TextStyle(
                                                color: AuthColors.primary,
                                              ),
                                            ),
                                            TextSpan(text: ' and '),
                                            TextSpan(
                                              text: 'Privacy Policy',
                                              style: TextStyle(
                                                color: AuthColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 28),

                              Consumer<AuthProvider>(
                                builder: (_, auth, __) => AuthPrimaryButton(
                                  label: 'Sign Up',
                                  isLoading: auth.isLoading,
                                  onTap: _signup,
                                  useGradient: true,
                                ),
                              ),

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
                                          text: 'Already have an account? ',
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
