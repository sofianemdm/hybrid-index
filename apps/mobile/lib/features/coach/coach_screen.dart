import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../log/log_wod_screen.dart';

const _attributes = ['engine', 'speed', 'strength', 'power', 'muscular_endurance', 'hybrid'];

/// Coach : choisis un axe à améliorer → Index projeté + séances ciblées (avec/sans matériel).
class CoachScreen extends ConsumerStatefulWidget {
  /// Axe pré-sélectionné (ex. clic sur « Hybride » dans le radar) ; null = point faible auto.
  final String? initialAttribute;
  const CoachScreen({super.key, this.initialAttribute});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  String? _attribute; // null = point faible auto
  late Future<CoachResult> _future;

  @override
  void initState() {
    super.initState();
    _attribute = widget.initialAttribute;
    _load();
  }

  void _load() {
    _future = ref.read(apiClientProvider).coach(attribute: _attribute);
  }

  void _select(String? a) => setState(() {
        _attribute = a;
        _load();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coach'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HiSpace.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sur quel axe progresser ?',
                    style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: HiSpace.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Mon point faible', null),
                    ..._attributes.map((a) => _chip(HiLabels.attribute(a), a)),
                  ],
                ),
                const SizedBox(height: HiSpace.lg),
                FutureBuilder<CoachResult>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
                    }
                    if (snap.hasError) {
                      return Text('${snap.error}', style: TextStyle(color: HiColors.error));
                    }
                    return _content(snap.data!);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(CoachResult r) {
    final color = HiColors.attribute(r.targetAttribute);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Carte Index projeté
        Container(
          padding: const EdgeInsets.all(HiSpace.lg),
          decoration: BoxDecoration(
            color: HiColors.bgElevated,
            borderRadius: BorderRadius.circular(HiRadius.lg),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Text('Si tu progresses sur ${HiLabels.attribute(r.targetAttribute)}',
                  style: TextStyle(color: HiColors.textSecondary)),
              const SizedBox(height: HiSpace.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${r.current}',
                      style: TextStyle(color: HiColors.textSecondary, fontSize: 28, fontWeight: FontWeight.w700)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Icon(Icons.arrow_forward, color: HiColors.textTertiary),
                  ),
                  Text('${r.projected}',
                      style: TextStyle(color: HiColors.brandPrimary, fontSize: 40, fontWeight: FontWeight.w800)),
                ],
              ),
              if (r.delta > 0)
                Text('+${r.delta} points potentiels',
                    style: TextStyle(color: HiColors.success, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: HiSpace.lg),
        Text('Séances pour ${HiLabels.attribute(r.targetAttribute)}',
            style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: HiSpace.sm),
        if (r.sessions.isEmpty)
          Text('Aucune séance pour cet axe avec ton matériel.', style: TextStyle(color: HiColors.textTertiary))
        else
          ...r.sessions.map((s) => _sessionCard(s, color)),
        const SizedBox(height: HiSpace.md),
        Builder(
          builder: (context) => OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.timer_outlined, size: 18),
            label: const Text('Faire une séance notée & enregistrer mon temps'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogWodScreen())),
          ),
        ),
      ],
    );
  }

  Widget _sessionCard(CoachSession s, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: HiSpace.sm),
      child: Padding(
        padding: const EdgeInsets.all(HiSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.name,
                      style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                ),
                _tag('${s.durationMin} min', HiColors.textTertiary),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _tag(_intensityLabel(s.intensity), color),
                const SizedBox(width: 6),
                _tag(s.requiresEquipment ? 'Matériel' : 'Sans matériel',
                    s.requiresEquipment ? HiColors.warn : HiColors.success),
              ],
            ),
            const SizedBox(height: 8),
            Text(s.description, style: TextStyle(color: HiColors.textSecondary, fontSize: 13, height: 1.4)),
          ],
        ),
      ),
    );
  }

  String _intensityLabel(String i) =>
      i == 'high' ? 'Intense' : (i == 'medium' ? 'Modéré' : 'Léger');

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(HiRadius.pill),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _chip(String label, String? value) {
    final active = _attribute == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      showCheckmark: false,
      selectedColor: HiColors.brandPrimary,
      backgroundColor: HiColors.bgElevated2,
      labelStyle: TextStyle(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w600),
      side: BorderSide(color: HiColors.strokeSubtle),
      onSelected: (_) => _select(value),
    );
  }
}
