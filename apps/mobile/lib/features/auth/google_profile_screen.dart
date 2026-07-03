import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';

/// Complément de profil à la PREMIÈRE connexion Google (Google ne fournit pas date de naissance,
/// sexe ni objectif — nécessaires à l'age-gating et au scoring).
class GoogleProfileScreen extends ConsumerStatefulWidget {
  final String idToken;
  const GoogleProfileScreen({super.key, required this.idToken});

  @override
  ConsumerState<GoogleProfileScreen> createState() => _GoogleProfileScreenState();
}

class _GoogleProfileScreenState extends ConsumerState<GoogleProfileScreen> {
  final _displayName = TextEditingController();
  DateTime? _dob;
  String _sex = 'male';
  String _equipment = 'equipped';
  bool _loading = false;

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: AppLocalizations.of(context).authBirthdate,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (_displayName.text.trim().length < 2) {
      _toast(AppLocalizations.of(context).gpUsernameMin);
      return;
    }
    if (_dob == null) {
      _toast('Renseigne ta date de naissance.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(sessionProvider.notifier).loginWithGoogle(widget.idToken, profile: {
        'displayName': _displayName.text.trim(),
        'dateOfBirth': _dob!.toIso8601String().split('T').first,
        'sex': _sex,
        'equipmentPref': _equipment,
      });
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst); // AuthGate prend le relais
    } on ApiException catch (e) {
      _toast(e.code == 'AGE_RESTRICTED' ? 'Tu dois avoir au moins 15 ans.' : e.message);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.gpTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HiSpace.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.gpSubtitle, style: TextStyle(color: HiColors.textSecondary)),
                const SizedBox(height: HiSpace.lg),
                TextField(
                  controller: _displayName,
                  decoration: InputDecoration(labelText: t.authUsername, prefixIcon: const Icon(Icons.person_outline)),
                ),
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
                _choices(t.authSexLabel, {'male': t.authSexMale, 'female': t.authSexFemale}, _sex,
                    (v) => setState(() => _sex = v)),
                const SizedBox(height: HiSpace.md),
                _choices(t.gpEquipmentShort, {'none': t.authEquipmentNone, 'equipped': t.authEquipmentEquipped},
                    _equipment, (v) => setState(() => _equipment = v)),
                const SizedBox(height: HiSpace.xl),
                HiButton(label: t.authCreateAccount, loading: _loading, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _choices(String label, Map<String, String> options, String value, ValueChanged<String> onChanged) {
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
              showCheckmark: false,
              selectedColor: HiColors.brandPrimary,
              backgroundColor: HiColors.bgElevated2,
              labelStyle: TextStyle(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w600),
              side: BorderSide(color: HiColors.strokeSubtle),
              onSelected: (_) => onChanged(e.key),
            );
          }).toList(),
        ),
      ],
    );
  }
}
