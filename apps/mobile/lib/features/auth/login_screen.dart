import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_ambient_background.dart';
import '../../widgets/hi_button.dart';
import 'apple_button.dart';
import 'auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'google_button.dart';
import 'google_profile_screen.dart';
import 'signup_screen.dart';

/// Écran CONNEXION (email + mot de passe, Google/Apple en option). Sombre AAA.
/// À la réussite, la session passe `loggedIn` et l'AuthGate enchaîne (Home / onboarding).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  String? _banner; // erreur serveur inline

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _emailError(AppLocalizations t) {
    if (!_emailTouched) return null;
    return kEmailRegExp.hasMatch(_email.text.trim()) ? null : t.authInvalidEmail;
  }

  String? _passwordError(AppLocalizations t) {
    if (!_passwordTouched) return null;
    return _password.text.isEmpty ? t.authPasswordTooShort : null;
  }

  bool get _canSubmit =>
      kEmailRegExp.hasMatch(_email.text.trim()) && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;
    final t = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _banner = null;
    });
    try {
      await ref.read(sessionProvider.notifier).login(_email.text.trim(), _password.text);
      // AuthGate prend le relais.
    } on ApiException catch (e) {
      setState(() => _banner = _messageFor(e, t));
      HapticFeedback.lightImpact();
    } catch (_) {
      setState(() => _banner = t.authGenericFail);
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(ApiException e, AppLocalizations t) {
    if (e.status == 401 || e.code == 'UNAUTHENTICATED') return t.authInvalidCredentials;
    if (e.code == 'NETWORK' || e.status == 0) return t.authNetworkError;
    return t.authGenericFail;
  }

  Future<void> _handleGoogle(String idToken) async {
    final t = AppLocalizations.of(context);
    try {
      await ref.read(sessionProvider.notifier).loginWithGoogle(idToken);
    } on ApiException catch (e) {
      final needsProfile = e.details?['needsProfile'] == true ||
          (e.code == 'VALIDATION_ERROR' && e.status == 400);
      if (needsProfile) {
        if (!mounted) return;
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => GoogleProfileScreen(idToken: idToken)));
      } else if (e.code == 'AGE_RESTRICTED') {
        setState(() => _banner = t.ageRestricted);
      } else if (e.status == 409 || e.code == 'CONFLICT') {
        setState(() => _banner = t.authConflict);
      } else {
        setState(() => _banner = _messageFor(e, t));
      }
    } catch (_) {
      setState(() => _banner = t.authGenericFail);
    }
  }

  Future<void> _handleApple(String identityToken) async {
    final t = AppLocalizations.of(context);
    try {
      await ref.read(sessionProvider.notifier).loginWithApple(identityToken);
    } on ApiException catch (e) {
      if (e.details?['needsProfile'] == true) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => GoogleProfileScreen(idToken: identityToken, provider: 'apple')));
      } else if (e.code == 'AGE_RESTRICTED') {
        setState(() => _banner = t.ageRestricted);
      } else {
        setState(() => _banner = _messageFor(e, t));
      }
    } catch (_) {
      setState(() => _banner = t.authGenericFail);
    }
  }

  void _goSignup() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: HiAmbientBackground(
        heroHalo: true,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: HiSpace.gutter, vertical: HiSpace.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: HiSpace.lg),
                    const AuthWordmark(),
                    const SizedBox(height: HiSpace.xl),
                    Text(t.authLoginTitle,
                        textAlign: TextAlign.center,
                        style: HiType.titleXL.copyWith(color: HiColors.textPrimary)),
                    const SizedBox(height: HiSpace.xs),
                    Text(t.authLoginSubtitle,
                        textAlign: TextAlign.center,
                        style: HiType.body.copyWith(color: HiColors.textSecondary)),
                    const SizedBox(height: HiSpace.lg),
                    HiFormBanner(message: _banner),
                    IgnorePointer(
                      ignoring: _loading,
                      child: Opacity(
                        opacity: _loading ? 0.6 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            HiAuthField(
                              controller: _email,
                              label: t.authEmail,
                              hint: t.authEmailHint,
                              prefixIcon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              errorText: _emailError(t),
                              onChanged: (_) => setState(() {
                                if (_email.text.isNotEmpty) _emailTouched = true;
                              }),
                            ),
                            HiAuthField(
                              controller: _password,
                              label: t.authPassword,
                              prefixIcon: Icons.lock_outline,
                              obscure: _obscure,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              errorText: _passwordError(t),
                              onChanged: (_) => setState(() => _passwordTouched = true),
                              onSubmitted: (_) => _submit(),
                              suffix: HiPasswordToggle(
                                obscured: _obscure,
                                onToggle: () => setState(() => _obscure = !_obscure),
                                showLabel: t.authShowPassword,
                                hideLabel: t.authHidePassword,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: HiGhostButton(
                                label: t.authForgotLink,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ForgotPasswordScreen(initialEmail: _email.text.trim()),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: HiSpace.md),
                    HiButton(
                      label: t.authSignInAction,
                      loading: _loading,
                      onPressed: _canSubmit ? _submit : null,
                    ),
                    if (Env.googleEnabled || AppleSignInButton.supported) ...[
                      const SizedBox(height: HiSpace.lg),
                      _OrDivider(label: t.authOr),
                      const SizedBox(height: HiSpace.md),
                      if (Env.googleEnabled)
                        Center(child: GoogleSignInButton(onToken: _handleGoogle, onError: _showError)),
                      if (AppleSignInButton.supported) ...[
                        const SizedBox(height: HiSpace.sm),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: AppleSignInButton(onToken: _handleApple, onError: _showError),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: HiSpace.lg),
                    AuthSwitchLink(label: t.authNoAccountSwitch, onTap: _goSignup),
                    const SizedBox(height: HiSpace.md),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _banner = message);
  }
}

/// Séparateur « ── ou ── ».
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: HiColors.strokeSubtle)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HiSpace.md),
          child: Text(label, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
        ),
        Expanded(child: Divider(color: HiColors.strokeSubtle)),
      ],
    );
  }
}
