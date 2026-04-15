import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthRequiredDialog extends StatelessWidget {
  final VoidCallback? onSignIn;
  final VoidCallback? onDismiss;

  const AuthRequiredDialog({super.key, this.onSignIn, this.onDismiss});

  static const _bg = Color(0xFF0B1326);
  static const _glassCard = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _onPrimary = Color(0xFF00344D);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outlineVar = Color(0xFF3E4850);

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onSignIn,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) =>
          AuthRequiredDialog(onSignIn: onSignIn, onDismiss: onDismiss),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _glassCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: _primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sign in Required',
              style: TextStyle(
                color: _onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sign in to access this feature',
              style: TextStyle(color: _onVariant, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                if (onSignIn != null) {
                  onSignIn!();
                } else {
                  context.go('/login');
                }
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    color: _onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                onDismiss?.call();
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _outlineVar.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Continue as Guest',
                  style: TextStyle(
                    color: _onVariant,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
