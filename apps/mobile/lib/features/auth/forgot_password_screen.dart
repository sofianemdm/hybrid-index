import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';

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

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _sendCode() async {
    final t = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).forgotPassword(_email.text.trim());
      setState(() => _sent = true);
      _toast(t.authForgotSent);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    final t = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref
          .read(apiClientProvider)
          .resetPassword(_email.text.trim(), _code.text.trim(), _password.text);
      _toast(t.authForgotDone);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      _toast(e.code == 'RESET_INVALID' ? t.authForgotInvalid : e.message);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.authForgotTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HiSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.authForgotIntro,
                      style: HiType.body.copyWith(color: HiColors.textSecondary)),
                  const SizedBox(height: HiSpace.lg),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_sent,
                    decoration: InputDecoration(
                        labelText: t.authEmail, prefixIcon: const Icon(Icons.mail_outline)),
                  ),
                  if (_sent) ...[
                    const SizedBox(height: HiSpace.md),
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                          labelText: t.authForgotCode,
                          counterText: '',
                          prefixIcon: const Icon(Icons.pin_outlined)),
                    ),
                    const SizedBox(height: HiSpace.md),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_loading) _reset();
                      },
                      decoration: InputDecoration(
                          labelText: t.authForgotNewPassword,
                          prefixIcon: const Icon(Icons.lock_outline)),
                    ),
                  ],
                  const SizedBox(height: HiSpace.xl),
                  HiButton(
                    label: _sent ? t.authForgotConfirm : t.authForgotSend,
                    loading: _loading,
                    onPressed: _sent ? _reset : _sendCode,
                  ),
                  if (_sent) ...[
                    const SizedBox(height: HiSpace.sm),
                    TextButton(
                      onPressed: _loading ? null : _sendCode,
                      child: Text(t.authForgotSend,
                          style: TextStyle(color: HiColors.textTertiary)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
