import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';

/// Réglages de notifications : activer/désactiver chaque type, heures de silence, plafond/jour.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _triggers = [];
  Map<String, bool> _prefs = {};
  int _dailyCap = 2;
  String _quietStart = '22:00';
  String _quietEnd = '07:00';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await ref.read(apiClientProvider).notificationPrefs();
      final prefs = (j['prefs'] as Map?)?.map((k, v) => MapEntry(k.toString(), v == true)) ?? {};
      final quiet = (j['quietHours'] as Map?) ?? {};
      setState(() {
        _triggers = ((j['triggers'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _prefs = Map<String, bool>.from(prefs);
        _dailyCap = (j['dailyCap'] as num?)?.toInt() ?? 2;
        _quietStart = quiet['start']?.toString() ?? '22:00';
        _quietEnd = quiet['end']?.toString() ?? '07:00';
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _toast('$e');
    }
  }

  bool _enabled(String key) => _prefs[key] != false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).updateNotificationPrefs({
        'prefs': _prefs,
        'quietHours': {'start': _quietStart, 'end': _quietEnd},
        'dailyCap': _dailyCap,
      });
      if (!mounted) return;
      _toast('Préférences enregistrées.');
      Navigator.of(context).pop();
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(bool start) async {
    final parts = (start ? _quietStart : _quietEnd).split(':');
    final initial = TimeOfDay(hour: int.tryParse(parts[0]) ?? 22, minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final s = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() => start ? _quietStart = s : _quietEnd = s);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages des notifications'), backgroundColor: Colors.transparent, elevation: 0),
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
                      Text('Heures de silence', style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _timeButton('Début', _quietStart, () => _pickTime(true))),
                          const SizedBox(width: HiSpace.md),
                          Expanded(child: _timeButton('Fin', _quietEnd, () => _pickTime(false))),
                        ],
                      ),
                      const SizedBox(height: HiSpace.lg),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Maximum par jour', style: TextStyle(color: HiColors.textPrimary)),
                          ),
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline, color: HiColors.textSecondary),
                            onPressed: _dailyCap > 0 ? () => setState(() => _dailyCap--) : null,
                          ),
                          Text('$_dailyCap', style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                          IconButton(
                            icon: Icon(Icons.add_circle_outline, color: HiColors.textSecondary),
                            onPressed: _dailyCap < 10 ? () => setState(() => _dailyCap++) : null,
                          ),
                        ],
                      ),
                      Divider(color: HiColors.strokeSubtle),
                      const SizedBox(height: HiSpace.sm),
                      Text('Types de notifications', style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: HiSpace.sm),
                      ..._triggers.map(_triggerRow),
                      const SizedBox(height: HiSpace.lg),
                      HiButton(label: 'Enregistrer', loading: _saving, onPressed: _save),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _timeButton(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HiRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value, style: TextStyle(color: HiColors.textPrimary)),
      ),
    );
  }

  Widget _triggerRow(Map<String, dynamic> t) {
    final key = t['key']?.toString() ?? '';
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: HiColors.brandPrimary,
      value: _enabled(key),
      title: Text(t['title']?.toString() ?? key, style: TextStyle(color: HiColors.textPrimary, fontSize: 14)),
      subtitle: Text(t['body']?.toString() ?? '',
          maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
      onChanged: (v) => setState(() => _prefs[key] = v),
    );
  }
}
