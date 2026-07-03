import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import 'google_button.dart';
import 'apple_button.dart';
import 'google_profile_screen.dart';
import 'forgot_password_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/share_links.dart';

/// Connexion / inscription. L'inscription pose l'age-gate (15+) et le profil de base.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _register = true;
  bool _loading = false;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  DateTime? _dob;
  String _sex = 'male';
  String _equipment = 'equipped';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    if (_register && _dob == null) {
      _toast('Renseigne ta date de naissance.');
      return;
    }
    setState(() => _loading = true);
    try {
      final notifier = ref.read(sessionProvider.notifier);
      if (_register) {
        await notifier.register({
          'email': _email.text.trim(),
          'password': _password.text,
          'displayName': _displayName.text.trim(),
          'dateOfBirth': _dob!.toIso8601String().split('T').first,
          'sex': _sex,
          'equipmentPref': _equipment,
        });
      } else {
        await notifier.login(_email.text.trim(), _password.text);
      }
      // AuthGate prend le relais (onboarding ou home).
    } on ApiException catch (e) {
      _toast(e.code == 'AGE_RESTRICTED' ? t.ageRestricted : e.message);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _handleGoogle(String idToken) async {
    final t = AppLocalizations.of(context);
    try {
      await ref.read(sessionProvider.notifier).loginWithGoogle(idToken);
      // AuthGate prend le relais (onboarding ou home).
    } on ApiException catch (e) {
      if (e.details?['needsProfile'] == true) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => GoogleProfileScreen(idToken: idToken)));
      } else {
        _toast(e.code == 'AGE_RESTRICTED' ? t.ageRestricted : e.message);
      }
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _handleApple(String identityToken) async {
    final t = AppLocalizations.of(context);
    try {
      await ref.read(sessionProvider.notifier).loginWithApple(identityToken);
      // AuthGate prend le relais (onboarding ou home).
    } on ApiException catch (e) {
      if (e.details?['needsProfile'] == true) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => GoogleProfileScreen(idToken: identityToken, provider: 'apple')));
      } else {
        _toast(e.code == 'AGE_RESTRICTED' ? t.ageRestricted : e.message);
      }
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: 'Date de naissance',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HiSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: HiSpace.xl),
                  // Logo : pastille marque + wordmark Rajdhani.
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: HiColors.brandGradient,
                        boxShadow: HiShadow.glowBrand(0.3),
                      ),
                      child: Icon(Icons.bolt_rounded, color: HiColors.textOnBrand, size: 36),
                    ),
                  ),
                  const SizedBox(height: HiSpace.md),
                  Text('ATHLETE LEAGUE',
                      textAlign: TextAlign.center,
                      style: HiType.displayL.copyWith(fontSize: 36, color: HiColors.textPrimary, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(t.appTagline,
                      textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textSecondary)),
                  const SizedBox(height: HiSpace.xl),
                  _SegToggle(
                    left: t.authSignUp,
                    right: t.authLogIn,
                    isLeft: _register,
                    onChanged: (v) => setState(() => _register = v),
                  ),
                  const SizedBox(height: HiSpace.lg),
                  if (_register) ...[
                    TextField(
                      controller: _displayName,
                      decoration: InputDecoration(labelText: t.authUsername, prefixIcon: const Icon(Icons.person_outline)),
                    ),
                    const SizedBox(height: HiSpace.md),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: t.authEmail, prefixIcon: const Icon(Icons.mail_outline)),
                  ),
                  const SizedBox(height: HiSpace.md),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    // Entrée valide directement (surtout en connexion : le mot de passe est le dernier champ).
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_loading) _submit();
                    },
                    decoration: InputDecoration(labelText: t.authPassword, prefixIcon: const Icon(Icons.lock_outline)),
                  ),
                  if (!_register)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim()),
                          ),
                        ),
                        child: Text(t.authForgotLink,
                            style: HiType.caption.copyWith(color: HiColors.brandPrimary)),
                      ),
                    ),
                  if (_register) ...[
                    const SizedBox(height: HiSpace.md),
                    InkWell(
                      onTap: _pickDob,
                      borderRadius: BorderRadius.circular(HiRadius.md),
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: t.authBirthdate, prefixIcon: const Icon(Icons.cake_outlined)),
                        child: Text(
                          _dob == null ? t.authPickDate : _dob!.toIso8601String().split('T').first,
                          style: TextStyle(color: _dob == null ? HiColors.textTertiary : HiColors.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(height: HiSpace.lg),
                    _ChoiceRow(
                      label: t.authSexLabel,
                      options: {'male': t.authSexMale, 'female': t.authSexFemale},
                      value: _sex,
                      onChanged: (v) => setState(() => _sex = v),
                    ),
                    const SizedBox(height: HiSpace.md),
                    _ChoiceRow(
                      label: t.authEquipmentLabel,
                      options: {'none': t.authEquipmentNone, 'equipped': t.authEquipmentEquipped},
                      value: _equipment,
                      onChanged: (v) => setState(() => _equipment = v),
                    ),
                  ],
                  const SizedBox(height: HiSpace.xl),
                  HiButton(
                    label: _register ? t.authCreateAccount : t.authSignInAction,
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  // Mention légale (exigence stores) : CGU + politique de confidentialité,
                  // consultables AVANT la création du compte.
                  if (_register) ...[
                    const SizedBox(height: HiSpace.sm),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(t.authLegalNotice,
                            style: HiType.caption.copyWith(color: HiColors.textTertiary)),
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
                          child: Text(t.legalPrivacyLink,
                              style: HiType.caption.copyWith(color: HiColors.brandPrimary)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: HiSpace.md),
                  if (Env.googleEnabled) ...[
                    Row(children: [
                      Expanded(child: Divider(color: HiColors.strokeSubtle)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('ou', style: TextStyle(color: HiColors.textTertiary)),
                      ),
                      Expanded(child: Divider(color: HiColors.strokeSubtle)),
                    ]),
                    const SizedBox(height: HiSpace.md),
                    Center(
                      child: GoogleSignInButton(onToken: _handleGoogle, onError: _toast),
                    ),
                    const SizedBox(height: HiSpace.md),
                  ],
                  // Sign in with Apple : uniquement iOS/macOS (exigé par l'App Store dès qu'un
                  // autre login social existe ; SizedBox.shrink ailleurs).
                  if (AppleSignInButton.supported) ...[
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: AppleSignInButton(onToken: _handleApple, onError: _toast),
                      ),
                    ),
                    const SizedBox(height: HiSpace.md),
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

class _SegToggle extends StatelessWidget {
  final String left;
  final String right;
  final bool isLeft;
  final ValueChanged<bool> onChanged;
  const _SegToggle({required this.left, required this.right, required this.isLeft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HiColors.bgElevated2,
        borderRadius: BorderRadius.circular(HiRadius.pill),
      ),
      child: Row(
        children: [
          _seg(left, isLeft, () => onChanged(true)),
          _seg(right, !isLeft, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _seg(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active ? HiColors.brandGradient : null,
            borderRadius: BorderRadius.circular(HiRadius.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? HiColors.textOnBrand : HiColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final String label;
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;
  const _ChoiceRow({required this.label, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.entries.map((e) {
            final active = e.key == value;
            return ChoiceChip(
              label: Text(e.value),
              selected: active,
              onSelected: (_) => onChanged(e.key),
              showCheckmark: false,
              selectedColor: HiColors.brandPrimary,
              backgroundColor: HiColors.bgElevated2,
              labelStyle: TextStyle(
                color: active ? HiColors.textOnBrand : HiColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: HiColors.strokeSubtle),
            );
          }).toList(),
        ),
      ],
    );
  }
}
