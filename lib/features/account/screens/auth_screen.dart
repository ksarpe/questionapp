import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/feedback/app_toast.dart';
import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';
import '../providers/session_providers.dart';

enum _AuthMode { password, register }

/// Presents the sign-in / register sheet as a modal that slides in from the
/// top of the screen and fades the background behind it.
Future<void> showAuthSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (_, _, _) => const _AuthSheet(),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

/// Top-anchored wrapper used by [showAuthSheet].
class _AuthSheet extends StatelessWidget {
  const _AuthSheet();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 8),
        child: const _AuthCard(),
      ),
    );
  }
}

/// Full-screen fallback so the auth flow can still be pushed as a route (and
/// rendered in isolation by tests). Reuses the exact same card.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(child: SingleChildScrollView(child: const _AuthCard())),
      ),
    );
  }
}

class _AuthCard extends ConsumerStatefulWidget {
  const _AuthCard();

  @override
  ConsumerState<_AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends ConsumerState<_AuthCard> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _AuthMode _mode = _AuthMode.password;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _isLogin => _mode == _AuthMode.password;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isConfigured = SupabaseService.isInitialised;
    final canUseGoogle = isConfigured && AppConfig.hasGoogleSignIn;

    // Leave room for the status bar and (when open) the keyboard, then let the
    // body scroll inside whatever height is left.
    final maxHeight =
        (media.size.height - media.padding.top - media.viewInsets.bottom - 24)
            .clamp(320.0, double.infinity);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: context.colors.cardSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.colors.hairline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHandleRow(context),
                    const SizedBox(height: 8),
                    _SegmentedTabs(
                      mode: _mode,
                      enabled: !_isSubmitting,
                      onChanged: _changeMode,
                    ),

                    const SizedBox(height: 22),
                    if (!isConfigured) ...[
                      _Notice(
                        icon: Icons.info_outline,
                        text: context.l10n.authMissingSupabaseConfig,
                      ),
                      const SizedBox(height: 18),
                    ] else if (!AppConfig.hasGoogleSignIn) ...[
                      _Notice(
                        icon: Icons.info_outline,
                        text: context.l10n.authMissingGoogleConfig,
                      ),
                      const SizedBox(height: 18),
                    ],
                    _fieldLabel(context.l10n.authEmailLabel),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      style: TextStyle(color: context.colors.ink),
                      decoration: _fieldDecoration(hint: 'you@example.com'),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 18),
                    _fieldLabel(context.l10n.authPasswordLabel),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isSubmitting,
                      obscureText: _obscurePassword,
                      textInputAction: _isLogin
                          ? TextInputAction.done
                          : TextInputAction.next,
                      autofillHints: _isLogin
                          ? const [AutofillHints.password]
                          : const [AutofillHints.newPassword],
                      style: TextStyle(color: context.colors.ink),
                      decoration: _fieldDecoration(
                        hint: '••••••••',
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? context.l10n.authShowPassword
                              : context.l10n.authHidePassword,
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: context.colors.subtle,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                      onFieldSubmitted: (_) {
                        if (_isLogin) _submit();
                      },
                    ),
                    if (!_isLogin) ...[
                      const SizedBox(height: 18),
                      _fieldLabel(context.l10n.authConfirmPasswordLabel),
                      TextFormField(
                        controller: _confirmPasswordController,
                        enabled: !_isSubmitting,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        style: TextStyle(color: context.colors.ink),
                        decoration: _fieldDecoration(hint: '••••••••'),
                        validator: _validateConfirmPassword,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                    if (_isLogin) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _isSubmitting ? null : _forgotPassword,
                          child: Text(
                            context.l10n.authForgotPassword,
                            style: const TextStyle(
                              color: AppTheme.spark,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _PrimaryButton(
                      label: _isLogin
                          ? context.l10n.signIn
                          : context.l10n.authCreateAccount,
                      loading: _isSubmitting,
                      onPressed: isConfigured ? _submit : null,
                    ),
                    const SizedBox(height: 22),
                    const _OrDivider(),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _SocialButton(
                            icon: Text(
                              'G',
                              style: TextStyle(
                                color: context.colors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                            label: 'Google',
                            onPressed: canUseGoogle && !_isSubmitting
                                ? _signInWithGoogle
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SocialButton(
                            icon: Icon(
                              Icons.apple,
                              color: context.colors.ink,
                              size: 22,
                            ),
                            label: 'Apple',
                            onPressed: _isSubmitting ? null : _signInWithApple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandleRow(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.subtle.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _CircleIconButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          _isLogin ? context.l10n.authNoAccount : context.l10n.authHaveAccount,
          style: TextStyle(color: context.colors.subtle, fontSize: 14),
        ),
        GestureDetector(
          onTap: _isSubmitting
              ? null
              : () => _changeMode(
                  _isLogin ? _AuthMode.register : _AuthMode.password,
                ),
          child: Text(
            _isLogin ? context.l10n.authSignUpFree : context.l10n.signIn,
            style: const TextStyle(
              color: AppTheme.spark,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _changeMode(_AuthMode mode) {
    if (_isSubmitting || mode == _mode) return;
    setState(() {
      _mode = mode;
      _formKey.currentState?.reset();
    });
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text,
      style: TextStyle(
        color: context.colors.subtle,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );

  InputDecoration _fieldDecoration({String? hint, Widget? suffixIcon}) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.colors.subtle),
      filled: true,
      fillColor: context.colors.accent,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: border(context.colors.hairline),
      focusedBorder: border(AppTheme.spark, 1.5),
      errorBorder: border(const Color(0xFFE5484D)),
      focusedErrorBorder: border(const Color(0xFFE5484D), 1.5),
      disabledBorder: border(context.colors.hairline),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return context.l10n.authEnterEmail;
    if (!email.contains('@') || !email.contains('.')) {
      return context.l10n.authEnterValidEmail;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return context.l10n.authEnterPassword;
    if (_mode == _AuthMode.register && password.length < 6) {
      return context.l10n.authMinPassword;
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return context.l10n.authPasswordsMismatch;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      switch (_mode) {
        case _AuthMode.password:
          await SupabaseService.signInWithPassword(
            email: email,
            password: password,
          );
          await ref.read(sessionProvider.notifier).refresh();
          if (!mounted) return;
          Navigator.of(context).maybePop();
        case _AuthMode.register:
          await SupabaseService.registerWithPassword(
            email: email,
            password: password,
          );
          await ref.read(sessionProvider.notifier).refresh();
          if (!mounted) return;
          final created = SupabaseService.currentUserHasAccount;
          _showMessage(
            created ? context.l10n.authAccountCreated : context.l10n.authConfirmEmail,
            type: created ? ToastType.success : ToastType.info,
          );
          if (SupabaseService.currentUserHasAccount) {
            Navigator.of(context).maybePop();
          }
      }
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message, type: ToastType.error);
    } catch (error) {
      if (mounted) _showMessage(error.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final user = await SupabaseService.signInWithGoogle();
      if (user == null) return; // user cancelled the picker
      await ref.read(sessionProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message, type: ToastType.error);
    } catch (error) {
      if (mounted) _showMessage(error.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _signInWithApple() {
    _showMessage(context.l10n.authAppleSoon);
  }

  void _forgotPassword() {
    _showMessage(context.l10n.authPasswordResetSoon);
  }

  void _showMessage(String message, {ToastType type = ToastType.info}) {
    if (!mounted) return;
    AppToast.show(context, message, type: type);
  }
}

/// Animated two-segment toggle between "sign in" and "create account".
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final _AuthMode mode;
  final bool enabled;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isLogin = mode == _AuthMode.password;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.accent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.hairline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pillWidth = constraints.maxWidth / 2;
          return SizedBox(
            height: 44,
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: isLogin
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    width: pillWidth,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6D5BC0), Color(0xFF4C3D86)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _tab(
                      context,
                      context.l10n.authTabSignIn,
                      _AuthMode.password,
                      isLogin,
                    ),
                    _tab(
                      context,
                      context.l10n.authTabSignUp,
                      _AuthMode.register,
                      !isLogin,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    String label,
    _AuthMode tabMode,
    bool selected,
  ) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged(tabMode) : null,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : context.colors.subtle,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// The big gradient call-to-action.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.spark.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 56,
              child: Center(
                child: loading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "—— LUB ——" separator.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: context.colors.hairline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            context.l10n.orDivider,
            style: TextStyle(
              color: context.colors.subtle,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.colors.hairline)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: context.colors.accent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: context.colors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.accent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: context.colors.subtle),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF4A3A1A)),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF171207),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFFFC857), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: context.colors.ink, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
