import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';

/// Login screen — VolantisLive dark glass design
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
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
    _passwordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (ok) {
      final destination = auth.isCreator ? '/creator' : '/home';
      context.go(destination);
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
          // Ambient glow blobs
          Positioned(
            bottom: -80,
            left: -80,
            child: _GlowBlob(
              color: AuthColors.secondary.withOpacity(0.07),
              size: 280,
            ),
          ),
          Positioned(
            top: 60,
            right: -60,
            child: _GlowBlob(
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
                        AuthTopBar(onBack: () => context.go('/onboarding')),
                        const SizedBox(height: 36),

                        // Headline
                        const Text(
                          'Welcome\nBack',
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
                          'Log in to access your space.',
                          style: TextStyle(
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
                              const AuthFieldLabel('Email'),
                              const SizedBox(height: 6),
                              AuthDarkInput(
                                controller: _emailController,
                                hint: 'name@domain.com',
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

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const AuthFieldLabel('Password'),
                                  GestureDetector(
                                    onTap: () {
                                      context.go('/forgot-password');
                                    },
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: AuthColors.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              AuthDarkInput(
                                controller: _passwordController,
                                hint: '••••••••',
                                obscure: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _login(),
                                autofillHints: const [AutofillHints.password],
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
                                    return 'Enter your password';
                                  }
                                  if (v.length < 6) return 'Min 6 characters';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 28),

                              Consumer<AuthProvider>(
                                builder: (_, auth, __) => AuthPrimaryButton(
                                  label: 'Log In',
                                  isLoading: auth.isLoading,
                                  onTap: _login,
                                  useGradient: false,
                                ),
                              ),

                              const SizedBox(height: 20),
                              const AuthDivider(label: 'Secure Access'),
                              const SizedBox(height: 20),

                              Center(
                                child: GestureDetector(
                                  onTap: () => context.go('/register'),
                                  child: RichText(
                                    text: const TextSpan(
                                      style: TextStyle(
                                        color: AuthColors.onVariant,
                                        fontSize: 14,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: "Don't have an account? ",
                                        ),
                                        TextSpan(
                                          text: 'Sign Up',
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

                              const SizedBox(height: 20),

                              Center(
                                child: GestureDetector(
                                  onTap: () => context.go('/home/guest'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AuthColors.outlineVar
                                            .withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Text(
                                      'Explore as Guest',
                                      style: TextStyle(
                                        color: AuthColors.onVariant,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        const AuthFeatureCard(
                          icon: Icons.auto_awesome_rounded,
                          iconBg: Color(0xFF6001D1),
                          iconColor: Color(0xFFC9AEFF),
                          title: 'AI-Powered Experience',
                          subtitle:
                              'Real-time transcription and adaptive noise cancellation for every session.',
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED AUTH DESIGN SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════

abstract class AuthColors {
  static const bg = Color(0xFF0B1326);
  static const glassCard = Color(0xFF171F33);
  static const surfaceHigh = Color(0xFF222A3D);
  static const primary = Color(0xFF89CEFF);
  static const primaryCont = Color(0xFF0EA5E9);
  static const secondary = Color(0xFFD2BBFF);
  static const onPrimary = Color(0xFF00344D);
  static const onSurface = Color(0xFFDAE2FD);
  static const onVariant = Color(0xFFBEC8D2);
  static const outline = Color(0xFF88929B);
  static const outlineVar = Color(0xFF3E4850);
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class AuthTopBar extends StatelessWidget {
  final VoidCallback? onBack;

  const AuthTopBar({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          GestureDetector(
            onTap: onBack,
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AuthColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
        ],
        const Text(
          'VolantisLive',
          style: TextStyle(
            color: AuthColors.primary,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            fontSize: 22,
            letterSpacing: -1.0,
          ),
        ),
      ],
    );
  }
}

// ── Glass card ────────────────────────────────────────────────────────────────

class AuthGlassCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final Alignment glowAlignment;

  const AuthGlassCard({
    super.key,
    required this.child,
    required this.glowColor,
    required this.glowAlignment,
  });

  @override
  Widget build(BuildContext context) {
    final isTopRight = glowAlignment == Alignment.topRight;

    return Container(
      decoration: BoxDecoration(
        color: AuthColors.glassCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            top: isTopRight ? -60 : null,
            bottom: isTopRight ? null : -60,
            right: isTopRight ? -60 : null,
            left: isTopRight ? null : -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor.withOpacity(0.12),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(24), child: child),
        ],
      ),
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

class AuthFieldLabel extends StatelessWidget {
  final String text;

  const AuthFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AuthColors.outline,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      ),
    );
  }
}

// ── Dark input ────────────────────────────────────────────────────────────────

class AuthDarkInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final List<String>? autofillHints;

  const AuthDarkInput({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.suffix,
    this.validator,
    this.onSubmitted,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      autofillHints: autofillHints,
      style: const TextStyle(color: AuthColors.onSurface, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AuthColors.outlineVar.withOpacity(0.7)),
        suffixIcon: suffix,
        filled: true,
        fillColor: AuthColors.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AuthColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFFB4AB), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFFB4AB), width: 2),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 11),
      ),
    );
  }
}

// ── Primary button ────────────────────────────────────────────────────────────

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  final bool useGradient;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onTap,
    this.useGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 56,
        decoration: BoxDecoration(
          gradient: useGradient
              ? const LinearGradient(
                  colors: [AuthColors.primary, AuthColors.primaryCont],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: useGradient ? null : AuthColors.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AuthColors.primary.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AuthColors.onPrimary,
                  ),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: AuthColors.onPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}

// ── Divider ───────────────────────────────────────────────────────────────────

class AuthDivider extends StatelessWidget {
  final String label;

  const AuthDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AuthColors.outlineVar.withOpacity(0.35),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AuthColors.outline,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AuthColors.outlineVar.withOpacity(0.35),
          ),
        ),
      ],
    );
  }
}

// ── Feature card ──────────────────────────────────────────────────────────────

class AuthFeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;

  const AuthFeatureCard({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AuthColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AuthColors.onVariant,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class AuthStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget indicator;

  const AuthStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.indicator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AuthColors.outline,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              indicator,
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  color: AuthColors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Checkbox ──────────────────────────────────────────────────────────────────

class AuthCheckBox extends StatelessWidget {
  final bool checked;

  const AuthCheckBox({super.key, required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: checked ? AuthColors.primary : AuthColors.surfaceHigh,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: checked ? AuthColors.primary : AuthColors.outlineVar,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, color: Color(0xFF001E2F), size: 13)
          : null,
    );
  }
}

// ── Glow blob ─────────────────────────────────────────────────────────────────

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
