import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/api_client.dart';
import '../../data/locale_mode.dart';
import '../../data/session.dart';
import '../../data/theme_mode.dart';
import '../../data/web_download.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import '../../widgets/bug_report.dart';
import '../avatar/dice_avatar_screen.dart';

/// Paramètres : modifier pseudo / objectif / matériel. Un changement d'objectif
/// recalcule l'Index (pondération par objectif) côté serveur.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _displayName = TextEditingController();
  String _equipment = 'equipped';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = await ref.read(apiClientProvider).me();
      setState(() {
        _displayName.text = me['displayName'] as String? ?? '';
        _equipment = me['equipmentPref'] as String? ?? 'equipped';
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _toast('$e');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Pseudo verrouillé (rejeté côté serveur) et objectif supprimé : on n'envoie que le matériel.
      await ref.read(apiClientProvider).updateMe({
        'equipmentPref': _equipment,
      });
      await ref.read(sessionProvider.notifier).refreshMe();
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      _toast(AppLocalizations.of(context).settingsUpdated);
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportData() async {
    try {
      final data = await ref.read(apiClientProvider).exportData();
      final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
      final ok = await downloadBytes(bytes, 'athlete-league-donnees.json');
      _toast(ok ? 'Données exportées 📥' : 'Export non supporté ici.');
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: HiColors.bgElevated,
        title: Text(AppLocalizations.of(context).deleteAccountTitle, style: TextStyle(color: HiColors.textPrimary)),
        content: Text(AppLocalizations.of(context).deleteAccountBody,
            style: TextStyle(color: HiColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context).commonCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).commonDelete, style: TextStyle(color: HiColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).deleteAccount();
      await ref.read(sessionProvider.notifier).logout();
      // Compte supprimé → on vide la pile de navigation pour revenir à l'AuthGate (écran
      // d'inscription), sinon l'écran Réglages (route empilée) resterait visible par-dessus.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      _toast('$e');
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Sélecteur de thème (Système / Clair / Sombre). Défaut = système ; choix persisté.
  Widget _themeSelector() {
    final mode = ref.watch(themeModeProvider);
    return SegmentedButton<ThemeMode>(
      segments: [
        ButtonSegment(
            value: ThemeMode.system,
            icon: const Icon(Icons.brightness_auto),
            label: Text(AppLocalizations.of(context).themeSystem)),
        ButtonSegment(
            value: ThemeMode.light,
            icon: const Icon(Icons.light_mode),
            label: Text(AppLocalizations.of(context).themeLight)),
        ButtonSegment(
            value: ThemeMode.dark,
            icon: const Icon(Icons.dark_mode),
            label: Text(AppLocalizations.of(context).themeDark)),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
    );
  }

  Widget _languageSelector() {
    final locale = ref.watch(localeProvider);
    final t = AppLocalizations.of(context);
    final sel = locale?.languageCode ?? 'system';
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'system', icon: const Icon(Icons.translate), label: Text(t.languageSystem)),
        ButtonSegment(value: 'fr', label: Text(t.languageFrench)),
        ButtonSegment(value: 'en', label: Text(t.languageEnglish)),
      ],
      selected: {sel},
      showSelectedIcon: false,
      onSelectionChanged: (s) =>
          ref.read(localeProvider.notifier).set(s.first == 'system' ? null : Locale(s.first)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
          title: Text(t.settingsTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(HiSpace.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t.authUsername, style: TextStyle(color: HiColors.textSecondary)),
                      const SizedBox(height: 8),
                      // Pseudo NON modifiable après création (verrouillé aussi côté serveur) → lecture seule.
                      InputDecorator(
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline)),
                        child: Text(_displayName.text.isEmpty ? '—' : _displayName.text,
                            style: TextStyle(color: HiColors.textPrimary)),
                      ),
                      const SizedBox(height: HiSpace.lg),
                      _ChoiceRow(
                        label: t.settingsEquipmentLabel,
                        options: {'none': t.settingsEquipmentNone, 'equipped': t.settingsEquipmentEquipped},
                        value: _equipment,
                        onChanged: (v) => setState(() => _equipment = v),
                      ),
                      const SizedBox(height: HiSpace.xl),
                      HiButton(label: t.wreSave, loading: _saving, onPressed: _save),
                      const SizedBox(height: HiSpace.lg),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: HiColors.strokeStrong),
                          foregroundColor: HiColors.textPrimary,
                        ),
                        icon: const Icon(Icons.face),
                        label: Text(t.settingsCustomizeAvatar),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DiceAvatarScreen()),
                        ),
                      ),
                      const SizedBox(height: HiSpace.xl),
                      Divider(color: HiColors.strokeSubtle),
                      const SizedBox(height: HiSpace.md),
                      Text(t.settingsAppearance, style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: HiSpace.sm),
                      _themeSelector(),
                      const SizedBox(height: HiSpace.xl),
                      Divider(color: HiColors.strokeSubtle),
                      const SizedBox(height: HiSpace.md),
                      Text(AppLocalizations.of(context).settingsLanguage,
                          style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: HiSpace.sm),
                      _languageSelector(),
                      const SizedBox(height: HiSpace.xl),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: HiColors.strokeStrong),
                          foregroundColor: HiColors.textPrimary,
                        ),
                        icon: const Icon(Icons.bug_report_outlined),
                        label: Text(t.bugReportTitle),
                        onPressed: () => showBugReportSheet(context),
                      ),
                      const SizedBox(height: HiSpace.xl),
                      Divider(color: HiColors.strokeSubtle),
                      const SizedBox(height: HiSpace.md),
                      Text(t.settingsPrivacy, style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: HiSpace.sm),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: HiColors.strokeStrong),
                          foregroundColor: HiColors.textPrimary,
                        ),
                        icon: const Icon(Icons.download),
                        label: Text(t.settingsExport),
                        onPressed: _exportData,
                      ),
                      const SizedBox(height: HiSpace.sm),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: HiColors.error.withValues(alpha: 0.6)),
                          foregroundColor: HiColors.error,
                        ),
                        icon: const Icon(Icons.delete_forever),
                        label: Text(t.settingsDeleteAccount),
                        onPressed: _confirmDelete,
                      ),
                      const SizedBox(height: HiSpace.md),
                      TextButton(
                        onPressed: () async {
                          await ref.read(sessionProvider.notifier).logout();
                          if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                        child: Text(t.settingsSignOut, style: TextStyle(color: HiColors.textTertiary)),
                      ),
                    ],
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
              showCheckmark: false,
              selectedColor: HiColors.brandPrimary,
              backgroundColor: HiColors.bgElevated2,
              labelStyle: TextStyle(
                color: active ? HiColors.textOnBrand : HiColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: HiColors.strokeSubtle),
              onSelected: (_) => onChanged(e.key),
            );
          }).toList(),
        ),
      ],
    );
  }
}
