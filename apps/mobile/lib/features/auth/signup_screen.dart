import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/env.dart';
import '../../core/share_links.dart';
import '../../data/api_client.dart';
import '../../data/diag_beacon.dart'; // TEMPORAIRE DIAG (04/07) : à retirer avant merge
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_ambient_background.dart';
import '../../widgets/hi_button.dart';
import 'apple_button.dart';
import 'auth_widgets.dart';
import 'google_button.dart';
import 'google_profile_screen.dart';

/// Écran CRÉER UN COMPTE : email, mot de passe (8+), pseudo, sexe, date de naissance.
/// À la réussite de `register`, la session passe `loggedIn` et l'AuthGate enchaîne
/// l'onboarding avatar existant — rien à router ici.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  DateTime? _dob;
  String _sex = 'male';
  // equipmentPref : on garde la valeur par défaut de l'ancien écran (non exposée ici).
  static const String _equipment = 'both';

  bool _obscure = true;
  bool _loading = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _usernameTouched = false;
  bool _dobTouched = false;
  String? _banner;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  String? _emailError(AppLocalizations t) {
    if (!_emailTouched) return null;
    return kEmailRegExp.hasMatch(_email.text.trim()) ? null : t.authInvalidEmail;
  }

  String? _passwordError(AppLocalizations t) {
    if (!_passwordTouched) return null;
    return _password.text.length >= 8 ? null : t.authPasswordTooShort;
  }

  String? _usernameError(AppLocalizations t) {
    if (!_usernameTouched) return null;
    return kUsernameRegExp.hasMatch(_displayName.text.trim()) ? null : t.authUsernameInvalid;
  }

  String? _dobError(AppLocalizations t) {
    if (!_dobTouched) return null;
    return _dob == null ? t.authBirthdateRequired : null;
  }

  bool get _canSubmit =>
      kEmailRegExp.hasMatch(_email.text.trim()) &&
      _password.text.length >= 8 &&
      kUsernameRegExp.hasMatch(_displayName.text.trim()) &&
      _dob != null;

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: AppLocalizations.of(context).authBirthdate,
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobTouched = true;
      });
    }
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _emailTouched = true;
      _passwordTouched = true;
      _usernameTouched = true;
      _dobTouched = true;
    });
    if (!_canSubmit || _loading) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _banner = null;
    });
    try {
      await ref.read(sessionProvider.notifier).register({
        'email': _email.text.trim(),
        'password': _password.text,
        'displayName': _displayName.text.trim(),
        'dateOfBirth': _dob!.toIso8601String().split('T').first,
        'sex': _sex,
        'equipmentPref': _equipment,
      });
      // AuthGate enchaîne l'onboarding avatar.
    } on ApiException catch (e) {
      setState(() => _banner = _messageFor(e, t));
      HapticFeedback.lightImpact();
    } catch (e) {
      diagBeacon('signup-generic-catch', {'errorType': e.runtimeType.toString(), 'error': '$e'}); // TEMPORAIRE DIAG
      setState(() => _banner = t.authGenericFail);
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(ApiException e, AppLocalizations t) {
    if (e.code == 'AGE_RESTRICTED') return t.ageRestricted;
    if (e.status == 409 || e.code == 'CONFLICT') return t.authConflict;
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
      } else {
        setState(() => _banner = _messageFor(e, t));
      }
    } catch (e) {
      diagBeacon('signup-generic-catch', {'errorType': e.runtimeType.toString(), 'error': '$e'}); // TEMPORAIRE DIAG
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
      } else {
        setState(() => _banner = _messageFor(e, t));
      }
    } catch (e) {
      diagBeacon('signup-generic-catch', {'errorType': e.runtimeType.toString(), 'error': '$e'}); // TEMPORAIRE DIAG
      setState(() => _banner = t.authGenericFail);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _banner = message);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
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
                    const AuthWordmark(),
                    const SizedBox(height: HiSpace.xl),
                    Text(t.authSignupTitle,
                        textAlign: TextAlign.center,
                        style: HiType.titleXL.copyWith(color: HiColors.textPrimary)),
                    const SizedBox(height: HiSpace.xs),
                    Text(t.authSignupSubtitle,
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
                              controller: _displayName,
                              label: t.authUsername,
                              hint: t.authUsernameHint,
                              prefixIcon: Icons.person_outline,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newUsername],
                              errorText: _usernameError(t),
                              onChanged: (_) => setState(() {
                                if (_displayName.text.isNotEmpty) _usernameTouched = true;
                              }),
                            ),
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
                              hint: t.authPasswordHint,
                              prefixIcon: Icons.lock_outline,
                              obscure: _obscure,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              helper: t.authPasswordHint,
                              errorText: _passwordError(t),
                              onChanged: (_) => setState(() {
                                if (_password.text.isNotEmpty) _passwordTouched = true;
                              }),
                              suffix: HiPasswordToggle(
                                obscured: _obscure,
                                onToggle: () => setState(() => _obscure = !_obscure),
                                showLabel: t.authShowPassword,
                                hideLabel: t.authHidePassword,
                              ),
                            ),
                            HiChoiceRow(
                              label: t.authSexLabel,
                              options: {'male': t.authSexMale, 'female': t.authSexFemale},
                              value: _sex,
                              onChanged: (v) => setState(() => _sex = v),
                            ),
                            const SizedBox(height: HiSpace.md),
                            HiDateField(
                              label: t.authBirthdate,
                              placeholder: t.authPickDate,
                              value: _dob,
                              onTap: _pickDob,
                              errorText: _dobError(t),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: HiSpace.sm),
                    HiButton(
                      label: t.authCreateAccount,
                      loading: _loading,
                      onPressed: _canSubmit ? _submit : null,
                    ),
                    const SizedBox(height: HiSpace.sm),
                    _LegalNotice(),
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
                    AuthSwitchLink(
                      label: t.authHaveAccountSwitch,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
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
}

/// Mention légale (exigence stores) : CGU + politique, consultables AVANT création du compte.
class _LegalNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(t.authLegalNotice, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
        TextButton(
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero),
          onPressed: () => launchUrl(Uri.parse(legalTermsUrl()), mode: LaunchMode.externalApplication),
          child: Text('CGU', style: HiType.caption.copyWith(color: HiColors.brandPrimary)),
        ),
        Text('·', style: HiType.caption.copyWith(color: HiColors.textTertiary)),
        TextButton(
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero),
          onPressed: () => launchUrl(Uri.parse(legalPrivacyUrl()), mode: LaunchMode.externalApplication),
          child: Text(t.legalPrivacyLink, style: HiType.caption.copyWith(color: HiColors.brandPrimary)),
        ),
      ],
    );
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
