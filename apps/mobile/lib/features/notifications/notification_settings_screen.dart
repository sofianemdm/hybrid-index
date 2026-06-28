import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../core/env.dart';
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
      _toast(AppLocalizations.of(context).notificationSettingsSaved);
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
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.notificationSettingsTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: HiColors.brandPrimary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(HiSpace.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Push pas encore branché (Firebase à venir) : on est HONNÊTE — les préférences
                      // sont mémorisées, mais aucune notification n'est encore envoyée (audit IC-11).
                      if (!Env.pushEnabled) ...[
                        Container(
                          padding: const EdgeInsets.all(HiSpace.md),
                          decoration: BoxDecoration(
                            color: HiColors.brandPrimary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(HiRadius.md),
                            border: Border.all(color: HiColors.brandPrimary.withValues(alpha: 0.30)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.notifications_paused_rounded, color: HiColors.brandPrimary, size: 20),
                              const SizedBox(width: HiSpace.sm),
                              Expanded(
                                child: Text(t.notificationSettingsComingSoon,
                                    style: HiType.caption.copyWith(color: HiColors.textSecondary, height: 1.35)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: HiSpace.lg),
                      ],
                      Text(t.notificationSettingsQuietHours, style: HiType.overline.copyWith(color: HiColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _timeButton(t.notificationSettingsStart, _quietStart, () => _pickTime(true))),
                          const SizedBox(width: HiSpace.md),
                          Expanded(child: _timeButton(t.notificationSettingsEnd, _quietEnd, () => _pickTime(false))),
                        ],
                      ),
                      const SizedBox(height: HiSpace.lg),
                      Row(
                        children: [
                          Expanded(
                            child: Text(t.notificationSettingsDailyCap, style: HiType.body.copyWith(color: HiColors.textPrimary)),
                          ),
                          IconButton(
                            tooltip: t.a11yDecrease,
                            icon: Icon(Icons.remove_circle_outline_rounded, color: HiColors.textSecondary),
                            onPressed: _dailyCap > 0 ? () => setState(() => _dailyCap--) : null,
                          ),
                          // a11y : la valeur courante est lue (« 2 par jour »), pas juste « 2 ».
                          Semantics(
                            label: t.a11yDailyCapValue(_dailyCap),
                            child: ExcludeSemantics(
                              child: Text('$_dailyCap', style: HiType.numericM.copyWith(color: HiColors.textPrimary)),
                            ),
                          ),
                          IconButton(
                            tooltip: t.a11yIncrease,
                            icon: Icon(Icons.add_circle_outline_rounded, color: HiColors.textSecondary),
                            onPressed: _dailyCap < 10 ? () => setState(() => _dailyCap++) : null,
                          ),
                        ],
                      ),
                      Divider(color: HiColors.strokeSubtle),
                      const SizedBox(height: HiSpace.sm),
                      Text(t.notificationSettingsTypes, style: HiType.overline.copyWith(color: HiColors.textSecondary)),
                      const SizedBox(height: HiSpace.sm),
                      ..._triggers.map(_triggerRow),
                      const SizedBox(height: HiSpace.lg),
                      HiButton(label: t.notificationSettingsSave, loading: _saving, onPressed: _save),
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
        child: Text(value, style: HiType.body.copyWith(color: HiColors.textPrimary)),
      ),
    );
  }

  Widget _triggerRow(Map<String, dynamic> t) {
    final key = t['key']?.toString() ?? '';
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: HiColors.brandPrimary,
      value: _enabled(key),
      title: Text(t['title']?.toString() ?? key, style: HiType.body.copyWith(color: HiColors.textPrimary)),
      subtitle: Text(t['body']?.toString() ?? '',
          maxLines: 2, overflow: TextOverflow.ellipsis, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
      onChanged: (v) => setState(() => _prefs[key] = v),
    );
  }
}
