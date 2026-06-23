import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import 'google_button.dart';
import 'google_profile_screen.dart';

/// Connexion / inscription. L'inscription pose l'age-gate (13+) et le profil de base.
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
  String _goal = 'hyrox';
  String _equipment = 'equipped';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
          'goal': _goal,
          'equipmentPref': _equipment,
        });
      } else {
        await notifier.login(_email.text.trim(), _password.text);
      }
      // AuthGate prend le relais (onboarding ou home).
    } on ApiException catch (e) {
      _toast(e.code == 'AGE_RESTRICTED' ? AppLocalizations.of(context).ageRestricted : e.message);
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
    try {
      await ref.read(sessionProvider.notifier).loginWithGoogle(idToken);
      // AuthGate prend le relais (onboarding ou home).
    } on ApiException catch (e) {
      if (e.details?['needsProfile'] == true) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => GoogleProfileScreen(idToken: idToken)));
      } else {
        _toast(e.code == 'AGE_RESTRICTED' ? AppLocalizations.of(context).ageRestricted : e.message);
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
                  Text('HYBRID INDEX',
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
                      decoration: const InputDecoration(labelText: 'Pseudo', prefixIcon: Icon(Icons.person_outline)),
                    ),
                    const SizedBox(height: HiSpace.md),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                  ),
                  const SizedBox(height: HiSpace.md),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mot de passe (8+)', prefixIcon: Icon(Icons.lock_outline)),
                  ),
                  if (_register) ...[
                    const SizedBox(height: HiSpace.md),
                    InkWell(
                      onTap: _pickDob,
                      borderRadius: BorderRadius.circular(HiRadius.md),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date de naissance', prefixIcon: Icon(Icons.cake_outlined)),
                        child: Text(
                          _dob == null ? 'Choisir…' : _dob!.toIso8601String().split('T').first,
                          style: TextStyle(color: _dob == null ? HiColors.textTertiary : HiColors.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(height: HiSpace.lg),
                    _ChoiceRow(
                      label: 'Sexe (sert au classement équitable)',
                      options: const {'male': 'Homme', 'female': 'Femme'},
                      value: _sex,
                      onChanged: (v) => setState(() => _sex = v),
                    ),
                    const SizedBox(height: HiSpace.md),
                    _ChoiceRow(
                      label: 'Objectif',
                      options: const {'hyrox': 'HYROX', 'crossfit_strength': 'CrossFit', 'all_round': 'Condition physique'},
                      value: _goal,
                      onChanged: (v) => setState(() => _goal = v),
                    ),
                    const SizedBox(height: HiSpace.md),
                    _ChoiceRow(
                      label: 'Matériel (modifiable plus tard) — « Équipé » donne accès aussi aux séances sans matériel',
                      options: const {'none': 'Sans matériel', 'equipped': 'Équipé'},
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
