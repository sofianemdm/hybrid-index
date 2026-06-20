import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../data/web_download.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import '../avatar/avatar_editor_screen.dart';

/// Paramètres : modifier pseudo / objectif / matériel. Un changement d'objectif
/// recalcule l'Index (pondération par objectif) côté serveur.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _displayName = TextEditingController();
  String _goal = 'hyrox';
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
        _goal = me['goal'] as String? ?? 'hyrox';
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
      await ref.read(apiClientProvider).updateMe({
        'displayName': _displayName.text.trim(),
        'goal': _goal,
        'equipmentPref': _equipment,
      });
      await ref.read(sessionProvider.notifier).refreshMe();
      ref.invalidate(myProfileProvider);
      ref.invalidate(rivalProvider);
      if (!mounted) return;
      _toast('Profil mis à jour.');
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
      final ok = await downloadBytes(bytes, 'hybrid-index-donnees.json');
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
        title: const Text('Supprimer le compte ?', style: TextStyle(color: HiColors.textPrimary)),
        content: const Text('Cette action est définitive : toutes tes données seront effacées.',
            style: TextStyle(color: HiColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: HiColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).deleteAccount();
      await ref.read(sessionProvider.notifier).logout();
    } catch (e) {
      _toast('$e');
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres'), backgroundColor: Colors.transparent, elevation: 0),
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
                      const Text('Pseudo', style: TextStyle(color: HiColors.textSecondary)),
                      const SizedBox(height: 8),
                      TextField(controller: _displayName),
                      const SizedBox(height: HiSpace.lg),
                      _ChoiceRow(
                        label: 'Objectif (modifie la pondération de ton Index)',
                        options: const {'hyrox': 'HYROX', 'crossfit_strength': 'CrossFit', 'all_round': 'Condition physique'},
                        value: _goal,
                        onChanged: (v) => setState(() => _goal = v),
                      ),
                      const SizedBox(height: HiSpace.lg),
                      _ChoiceRow(
                        label: 'Matériel — « Équipé » donne aussi accès au sans-matériel',
                        options: const {'none': 'Sans matériel', 'equipped': 'Équipé'},
                        value: _equipment,
                        onChanged: (v) => setState(() => _equipment = v),
                      ),
                      const SizedBox(height: HiSpace.xl),
                      HiButton(label: 'Enregistrer', loading: _saving, onPressed: _save),
                      const SizedBox(height: HiSpace.lg),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: HiColors.strokeStrong),
                          foregroundColor: HiColors.textPrimary,
                        ),
                        icon: const Icon(Icons.face),
                        label: const Text('Personnaliser mon avatar'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AvatarEditorScreen()),
                        ),
                      ),
                      const SizedBox(height: HiSpace.xl),
                      const Divider(color: HiColors.strokeSubtle),
                      const SizedBox(height: HiSpace.md),
                      const Text('Données & confidentialité (RGPD)',
                          style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: HiSpace.sm),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: HiColors.strokeStrong),
                          foregroundColor: HiColors.textPrimary,
                        ),
                        icon: const Icon(Icons.download),
                        label: const Text('Exporter mes données'),
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
                        label: const Text('Supprimer mon compte'),
                        onPressed: _confirmDelete,
                      ),
                      const SizedBox(height: HiSpace.md),
                      TextButton(
                        onPressed: () => ref.read(sessionProvider.notifier).logout(),
                        child: const Text('Se déconnecter', style: TextStyle(color: HiColors.textTertiary)),
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
        Text(label, style: const TextStyle(color: HiColors.textSecondary, fontSize: 13)),
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
              side: const BorderSide(color: HiColors.strokeSubtle),
              onSelected: (_) => onChanged(e.key),
            );
          }).toList(),
        ),
      ],
    );
  }
}
