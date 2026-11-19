import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/auth_service.dart';

/// Registration screen. Collects full name, username, email and password,
/// then creates a new account via [AuthService.register].
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _auth = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);
    try {
      await _auth.register(
        fullName: _fullNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Welcome to Ludo Royale! Your account is ready.'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
          ),
        );
      context.go('/home');
    } catch (e) {
      _showError('Registration failed: ${_humanError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanError(Object e) {
    final msg = e.toString();
    final match = RegExp(r"ApiException\(\d+\):\s*(.*)").firstMatch(msg);
    return match != null ? match.group(1)! : msg;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4A148C),
              Color(0xFF1565C0),
              Color(0xFF0A0E27),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.topLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white),
                            onPressed: () => context.go('/login'),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Mini logo
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: AppTheme.goldGradient(),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFC107)
                                      .withOpacity(0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.casino,
                                size: 36, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Create Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Join the royal arena in less than a minute',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _Card(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _LabeledField(
                                  label: 'Full Name',
                                  child: TextFormField(
                                    controller: _fullNameController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. Alex Carter',
                                      prefixIcon: Icon(Icons.badge_outlined,
                                          color: AppTheme.textSecondary),
                                    ),
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary),
                                    validator: (v) {
                                      final s = v?.trim() ?? '';
                                      if (s.isEmpty) {
                                        return 'Please enter your full name';
                                      }
                                      if (s.length < 2) {
                                        return 'Name seems too short';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _LabeledField(
                                  label: 'Username',
                                  child: TextFormField(
                                    controller: _usernameController,
                                    textInputAction: TextInputAction.next,
                                    textCapitalization:
                                        TextCapitalization.none,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. royalplayer',
                                      prefixIcon: Icon(Icons.alternate_email,
                                          color: AppTheme.textSecondary),
                                    ),
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary),
                                    validator: (v) {
                                      final s = v?.trim() ?? '';
                                      if (s.isEmpty) {
                                        return 'Please choose a username';
                                      }
                                      if (s.length < 3) {
                                        return 'Username must be at least 3 characters';
                                      }
                                      final valid = RegExp(
                                              r'^[a-zA-Z0-9_]+$')
                                          .hasMatch(s);
                                      if (!valid) {
                                        return 'Use letters, numbers or underscores only';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _LabeledField(
                                  label: 'Email',
                                  child: TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    textCapitalization:
                                        TextCapitalization.none,
                                    autofillHints: const [AutofillHints.email],
                                    decoration: const InputDecoration(
                                      hintText: 'you@example.com',
                                      prefixIcon: Icon(Icons.mail_outline,
                                          color: AppTheme.textSecondary),
                                    ),
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary),
                                    validator: (v) {
                                      final s = v?.trim() ?? '';
                                      if (s.isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      final valid = RegExp(
                                              r'^[\w.+-]+@[\w-]+\.[\w.-]+$')
                                          .hasMatch(s);
                                      if (!valid) {
                                        return 'Enter a valid email address';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _LabeledField(
                                  label: 'Password',
                                  child: TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.newPassword
                                    ],
                                    decoration: InputDecoration(
                                      hintText: 'At least 6 characters',
                                      prefixIcon: const Icon(Icons.lock_outline,
                                          color: AppTheme.textSecondary),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: AppTheme.textSecondary,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Please enter a password';
                                      }
                                      if (v.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _LabeledField(
                                  label: 'Confirm Password',
                                  child: TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.newPassword
                                    ],
                                    decoration: InputDecoration(
                                      hintText: 'Re-enter your password',
                                      prefixIcon: const Icon(Icons.lock_outline,
                                          color: AppTheme.textSecondary),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: AppTheme.textSecondary,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscureConfirmPassword =
                                                !_obscureConfirmPassword),
                                      ),
                                    ),
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary),
                                    onFieldSubmitted: (_) => _submit(),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Please confirm your password';
                                      }
                                      if (v != _passwordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 22),
                                SizedBox(
                                  height: 54,
                                  child: _GradientButton(
                                    label: 'Register',
                                    loading: _loading,
                                    onPressed: _submit,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Already have an account?',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 14,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _loading
                                          ? null
                                          : () => context.go('/login'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.accent,
                                      ),
                                      child: const Text(
                                        'Login',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Semi-transparent card wrapper using the brand card gradient.
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Field label + child input.
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Reusable gold-gradient CTA button with a loading spinner state.
class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = loading;
    return Opacity(
      opacity: disabled ? 0.7 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: disabled ? null : onPressed,
          child: Ink(
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient(),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC107).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
