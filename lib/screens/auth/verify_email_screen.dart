import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../repositories/auth_repository.dart';
import '../../utils/helpers.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_card.dart';

/// Screen shown after successful signup.
/// Instructs the user to check their email and verify their account.
class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isResending = false;
  bool _resendCooldown = false;

  Future<void> _resendEmail() async {
    if (_isResending || _resendCooldown) return;
    setState(() => _isResending = true);
    try {
      final repo = context.read<AuthRepository>();
      await repo.resendVerification(widget.email);
      if (!mounted) return;
      Helpers.showSuccessToast('Verification email sent! Check your inbox. 📧');
      setState(() => _resendCooldown = true);
      // Cooldown: prevent spamming for 60 seconds
      await Future.delayed(const Duration(seconds: 60));
      if (mounted) setState(() => _resendCooldown = false);
    } catch (e) {
      if (!mounted) return;
      Helpers.showErrorToast(e.toString());
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        isSlideshow: false,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.3),
                          AppTheme.secondaryColor.withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.mark_email_unread_rounded,
                      size: 48,
                      color: AppTheme.primaryColor,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(end: 1.06, duration: 2.seconds),

                  const SizedBox(height: 32),

                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Check Your Email',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'We sent a verification link to:',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            widget.email,
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Please click the link in the email to verify your account. '
                          'The link expires in 24 hours.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        // Resend Button
                        CustomButton(
                          label: _resendCooldown ? 'Email Sent ✓' : 'Resend Verification Email',
                          onPressed: _resendCooldown ? null : _resendEmail,
                          isLoading: _isResending,
                        ),

                        const SizedBox(height: 16),

                        // Back to login
                        TextButton.icon(
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Back to Login'),
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, AppRoutes.login);
                          },
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 500.ms).slideY(begin: 0.15, end: 0),

                  const SizedBox(height: 24),

                  // Tip card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Check your spam/junk folder if you don\'t see the email.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.amber.shade300),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade(delay: 300.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
