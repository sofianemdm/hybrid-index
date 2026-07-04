import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_ambient_background.dart';
import '../../widgets/hi_button.dart';
import 'auth_widgets.dart';

/// « Mot de passe oublié » en 2 étapes : email → code à 6 chiffres + nouveau mot de passe.
/// La 1re étape répond toujours pareil (l'api ne révèle jamais si l'email existe).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false; // étape 2 : le code a été demandé
  bool _loading = false;
  bool _obscure = true;
  String? _errorBanner;
  String? _successBanner;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _emailValid => kEmailRegExp.hasMatch(_email.text.trim());

  Future<void> _sendCode() async {
    if (!_emailValid || _loading) return;
    final t = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _errorBanner = null;
    });
    try {
      await ref.read(apiClientProvider).forgotPassword(_email.text.trim());
      setState(() {
        _sent = true;
        _successBanner = t.authForgotSent;
      });
    } on ApiException catch (e) {
      setState(() => _errorBanner =
          (e.code == 'NETWORK' || e.status == 0) ? t.authNetworkError : t.authGenericFail);
    } catch (_) {
      setState(() => _errorBanner = t.authGenericFail);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (_loading) return;
    final t = AppLocalizations.of(context);
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim()) || _password.text.length < 8) {
      setState(() => _errorBanner = t.authForgotInvalid);
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _errorBanner = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .resetPassword(_email.text.trim(), _code.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorBanner = e.code == 'RESET_INVALID'
          ? t.authForgotInvalid
          : ((e.code == 'NETWORK' || e.status == 0) ? t.authNetworkError : t.authGenericFail));
      HapticFeedback.lightImpact();
    } catch (_) {
      setState(() => _errorBanner = t.authGenericFail);
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(t.authForgotTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: HiAmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: HiSpace.gutter, vertical: HiSpace.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.authForgotIntro, style: HiType.body.copyWith(color: HiColors.textSecondary)),
                    const SizedBox(height: HiSpace.lg),
                    HiFormBanner(message: _errorBanner),
                    HiFormBanner(message: _successBanner, success: true),
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
                              enabled: !_sent,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) {
                                if (!_sent) _sendCode();
                              },
                            ),
                            if (_sent) ...[
                              HiAuthField(
                                controller: _code,
                                label: t.authForgotCode,
                                prefixIcon: Icons.pin_outlined,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => setState(() {}),
                              ),
                              HiAuthField(
                                controller: _password,
                                label: t.authForgotNewPassword,
                                hint: t.authPasswordHint,
                                prefixIcon: Icons.lock_outline,
                                obscure: _obscure,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.newPassword],
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) => _reset(),
                                suffix: HiPasswordToggle(
                                  obscured: _obscure,
                                  onToggle: () => setState(() => _obscure = !_obscure),
                                  showLabel: t.authShowPassword,
                                  hideLabel: t.authHidePassword,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: HiSpace.md),
                    HiButton(
                      label: _sent ? t.authForgotConfirm : t.authForgotSend,
                      loading: _loading,
                      onPressed: _sent ? _reset : (_emailValid ? _sendCode : null),
                    ),
                    if (_sent) ...[
                      const SizedBox(height: HiSpace.sm),
                      Center(
                        child: TextButton(
                          onPressed: _loading ? null : _sendCode,
                          child: Text(t.authForgotSend,
                              style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                        ),
                      ),
                    ],
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
