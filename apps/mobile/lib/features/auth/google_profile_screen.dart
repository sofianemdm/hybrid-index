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

/// Complément de profil à la PREMIÈRE connexion sociale (Google/Apple : ces fournisseurs ne
/// donnent ni date de naissance, ni sexe — nécessaires à l'age-gating et au scoring).
class GoogleProfileScreen extends ConsumerStatefulWidget {
  final String idToken;

  /// 'google' (défaut) ou 'apple' : choisit l'endpoint de connexion à la soumission.
  final String provider;
  const GoogleProfileScreen({super.key, required this.idToken, this.provider = 'google'});

  @override
  ConsumerState<GoogleProfileScreen> createState() => _GoogleProfileScreenState();
}

class _GoogleProfileScreenState extends ConsumerState<GoogleProfileScreen> {
  final _displayName = TextEditingController();
  DateTime? _dob;
  String _sex = 'male';
  static const String _equipment = 'both';
  bool _loading = false;
  bool _usernameTouched = false;
  bool _dobTouched = false;
  String? _banner;

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  String? _usernameError(AppLocalizations t) {
    if (!_usernameTouched) return null;
    return kUsernameRegExp.hasMatch(_displayName.text.trim()) ? null : t.authUsernameInvalid;
  }

  String? _dobError(AppLocalizations t) {
    if (!_dobTouched) return null;
    return _dob == null ? t.authBirthdateRequired : null;
  }

  bool get _canSubmit => kUsernameRegExp.hasMatch(_displayName.text.trim()) && _dob != null;

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
      final profile = {
        'displayName': _displayName.text.trim(),
        'dateOfBirth': _dob!.toIso8601String().split('T').first,
        'sex': _sex,
        'equipmentPref': _equipment,
      };
      final session = ref.read(sessionProvider.notifier);
      if (widget.provider == 'apple') {
        await session.loginWithApple(widget.idToken, profile: profile);
      } else {
        await session.loginWithGoogle(widget.idToken, profile: profile);
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst); // AuthGate prend le relais
    } on ApiException catch (e) {
      setState(() {
        if (e.code == 'AGE_RESTRICTED') {
          _banner = t.ageRestricted;
        } else if (e.status == 409 || e.code == 'CONFLICT') {
          _banner = t.authConflict;
        } else if (e.code == 'NETWORK' || e.status == 0) {
          _banner = t.authNetworkError;
        } else {
          _banner = t.authGenericFail;
        }
      });
      HapticFeedback.lightImpact();
    } catch (_) {
      setState(() => _banner = t.authGenericFail);
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
      appBar: AppBar(title: Text(t.gpTitle), backgroundColor: Colors.transparent, elevation: 0),
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
                    Text(t.gpSubtitle, style: HiType.body.copyWith(color: HiColors.textSecondary)),
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
                    const SizedBox(height: HiSpace.md),
                    HiButton(
                      label: t.authCreateAccount,
                      loading: _loading,
                      onPressed: _canSubmit ? _submit : null,
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
