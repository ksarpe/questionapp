import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';
import '../providers/session_providers.dart';

enum _AuthMode { emailLink, password, register }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _AuthMode _mode = _AuthMode.emailLink;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    final isConfigured = SupabaseService.isInitialised;

    return Scaffold(
      appBar: AppBar(title: const Text('Konto')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AuthHeader(session: session),
                        const SizedBox(height: 22),
                        _AuthModeSelector(
                          mode: _mode,
                          enabled: !_isSubmitting,
                          onChanged: (mode) {
                            setState(() {
                              _mode = mode;
                              _formKey.currentState?.reset();
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        if (!isConfigured) ...[
                          const _Notice(
                            icon: Icons.info_outline,
                            text:
                                'Brakuje konfiguracji Supabase. Uruchom aplikację z SUPABASE_URL i SUPABASE_ANON_KEY.',
                          ),
                          const SizedBox(height: 14),
                        ],
                        _AuthFormPanel(
                          formKey: _formKey,
                          mode: _mode,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          confirmPasswordController: _confirmPasswordController,
                          isSubmitting: _isSubmitting,
                          isConfigured: isConfigured,
                          obscurePassword: _obscurePassword,
                          submitLabel: _submitLabel,
                          submitIcon: _submitIcon,
                          onSubmit: _submit,
                          onTogglePassword: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          validateEmail: _validateEmail,
                          validatePassword: _validatePassword,
                          validateConfirmPassword: _validateConfirmPassword,
                        ),
                        const SizedBox(height: 10),
                        _SecondaryActions(
                          mode: _mode,
                          enabled: !_isSubmitting,
                          onModeChanged: (mode) => setState(() {
                            _mode = mode;
                            _formKey.currentState?.reset();
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String get _submitLabel => switch (_mode) {
    _AuthMode.emailLink => 'Wyślij link',
    _AuthMode.password => 'Zaloguj się',
    _AuthMode.register => 'Utwórz konto',
  };

  IconData get _submitIcon => switch (_mode) {
    _AuthMode.emailLink => Icons.send_outlined,
    _AuthMode.password => Icons.login,
    _AuthMode.register => Icons.person_add_alt_1_outlined,
  };

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Podaj email.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Podaj poprawny email.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Podaj hasło.';
    if (_mode == _AuthMode.register && password.length < 6) {
      return 'Minimum 6 znaków.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return 'Hasła nie są takie same.';
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
        case _AuthMode.emailLink:
          await SupabaseService.sendEmailLink(email);
          if (!mounted) return;
          _showMessage('Link wysłany. Sprawdź skrzynkę.');
        case _AuthMode.password:
          await SupabaseService.signInWithPassword(
            email: email,
            password: password,
          );
          await ref.read(sessionProvider.notifier).refresh();
          if (!mounted) return;
          Navigator.of(context).pop();
        case _AuthMode.register:
          await SupabaseService.registerWithPassword(
            email: email,
            password: password,
          );
          await ref.read(sessionProvider.notifier).refresh();
          if (!mounted) return;
          _showMessage(
            SupabaseService.currentUserHasAccount
                ? 'Konto utworzone.'
                : 'Sprawdź email i potwierdź konto.',
          );
          if (SupabaseService.currentUserHasAccount) {
            Navigator.of(context).pop();
          }
      }
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.accent),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.session});

  final SessionState? session;

  @override
  Widget build(BuildContext context) {
    final hasAccount = session?.hasAccount == true;
    final email = session?.email;
    final statusText = hasAccount
        ? email ?? 'Konto aktywne'
        : session?.isAnonymous == true
        ? 'Sesja gościa'
        : 'Konto';

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.accent)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                border: Border.all(color: AppTheme.accent),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                hasAccount
                    ? Icons.verified_user_outlined
                    : Icons.person_outline,
                color: hasAccount ? const Color(0xFF7CE38B) : AppTheme.ink,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Twoje konto',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.subtle),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthModeSelector extends StatelessWidget {
  const _AuthModeSelector({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final _AuthMode mode;
  final bool enabled;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AuthModeButton(
            mode: _AuthMode.emailLink,
            selected: mode == _AuthMode.emailLink,
            enabled: enabled,
            icon: Icons.mark_email_read_outlined,
            label: 'Link',
            onTap: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AuthModeButton(
            mode: _AuthMode.password,
            selected: mode == _AuthMode.password,
            enabled: enabled,
            icon: Icons.lock_open_outlined,
            label: 'Hasło',
            onTap: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AuthModeButton(
            mode: _AuthMode.register,
            selected: mode == _AuthMode.register,
            enabled: enabled,
            icon: Icons.person_add_alt_1_outlined,
            label: 'Nowe',
            onTap: onChanged,
          ),
        ),
      ],
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final _AuthMode mode;
  final bool selected;
  final bool enabled;
  final IconData icon;
  final String label;
  final ValueChanged<_AuthMode> onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppTheme.ink : AppTheme.accent;
    final background = selected ? AppTheme.ink : const Color(0xFF0B0B0B);
    final foreground = selected ? AppTheme.background : AppTheme.ink;

    return InkWell(
      onTap: enabled ? () => onTap(mode) : null,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: enabled ? background : AppTheme.accent,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({
    required this.formKey,
    required this.mode,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isSubmitting,
    required this.isConfigured,
    required this.obscurePassword,
    required this.submitLabel,
    required this.submitIcon,
    required this.onSubmit,
    required this.onTogglePassword,
    required this.validateEmail,
    required this.validatePassword,
    required this.validateConfirmPassword,
  });

  final GlobalKey<FormState> formKey;
  final _AuthMode mode;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isSubmitting;
  final bool isConfigured;
  final bool obscurePassword;
  final String submitLabel;
  final IconData submitIcon;
  final VoidCallback onSubmit;
  final VoidCallback onTogglePassword;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;
  final FormFieldValidator<String> validateConfirmPassword;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        border: Border.all(color: AppTheme.accent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: emailController,
                enabled: !isSubmitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: mode == _AuthMode.emailLink
                    ? TextInputAction.done
                    : TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: _inputDecoration(
                  label: 'Email',
                  icon: Icons.alternate_email,
                ),
                validator: validateEmail,
                onFieldSubmitted: (_) {
                  if (mode == _AuthMode.emailLink) onSubmit();
                },
              ),
              if (mode != _AuthMode.emailLink) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: passwordController,
                  enabled: !isSubmitting,
                  obscureText: obscurePassword,
                  textInputAction: mode == _AuthMode.register
                      ? TextInputAction.next
                      : TextInputAction.done,
                  autofillHints: mode == _AuthMode.register
                      ? const [AutofillHints.newPassword]
                      : const [AutofillHints.password],
                  decoration:
                      _inputDecoration(
                        label: 'Hasło',
                        icon: Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          tooltip: obscurePassword
                              ? 'Pokaż hasło'
                              : 'Ukryj hasło',
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: onTogglePassword,
                        ),
                      ),
                  validator: validatePassword,
                  onFieldSubmitted: (_) {
                    if (mode == _AuthMode.password) onSubmit();
                  },
                ),
              ],
              if (mode == _AuthMode.register) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmPasswordController,
                  enabled: !isSubmitting,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: _inputDecoration(
                    label: 'Powtórz hasło',
                    icon: Icons.verified_user_outlined,
                  ),
                  validator: validateConfirmPassword,
                  onFieldSubmitted: (_) => onSubmit(),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: isConfigured && !isSubmitting ? onSubmit : null,
                  icon: isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(submitIcon),
                  label: Text(submitLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppTheme.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.accent),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.ink),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({
    required this.mode,
    required this.enabled,
    required this.onModeChanged,
  });

  final _AuthMode mode;
  final bool enabled;
  final ValueChanged<_AuthMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final actions = switch (mode) {
      _AuthMode.emailLink => [
        _SecondaryAction('Mam hasło', _AuthMode.password),
        _SecondaryAction('Utwórz konto', _AuthMode.register),
      ],
      _AuthMode.password => [
        _SecondaryAction('Wyślij link', _AuthMode.emailLink),
        _SecondaryAction('Utwórz konto', _AuthMode.register),
      ],
      _AuthMode.register => [
        _SecondaryAction('Mam konto', _AuthMode.password),
        _SecondaryAction('Link na maila', _AuthMode.emailLink),
      ],
    };

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        for (final action in actions)
          TextButton(
            onPressed: enabled ? () => onModeChanged(action.mode) : null,
            child: Text(action.label),
          ),
      ],
    );
  }
}

class _SecondaryAction {
  const _SecondaryAction(this.label, this.mode);

  final String label;
  final _AuthMode mode;
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
        borderRadius: BorderRadius.circular(8),
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
                style: const TextStyle(color: AppTheme.ink, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
