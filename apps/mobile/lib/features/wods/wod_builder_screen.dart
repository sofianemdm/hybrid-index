import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import 'wod_detail_screen.dart';
import 'wod_format.dart';

const _formats = {
  'for_time': 'For Time',
  'amrap': 'AMRAP',
  'emom': 'EMOM',
  'chipper': 'Chipper',
  'interval': 'Intervalles',
  'tabata': 'Tabata',
  'strength': 'Force',
  'distance': 'Distance/Temps',
};

String _scoreTypeFor(String wodType) {
  switch (wodType) {
    case 'amrap':
    case 'emom':
    case 'tabata':
      return 'reps';
    case 'strength':
      return 'load';
    case 'distance':
      return 'distance';
    default:
      return 'time';
  }
}

class _Block {
  final MovementSummary movement;
  int amount;
  double? loadKg;
  _Block(this.movement, this.amount, this.loadKg);
}

/// Constructeur de séance : format + mouvements + aperçu live de l'estimation, puis publication.
class WodBuilderScreen extends ConsumerStatefulWidget {
  const WodBuilderScreen({super.key});

  @override
  ConsumerState<WodBuilderScreen> createState() => _WodBuilderScreenState();
}

class _WodBuilderScreenState extends ConsumerState<WodBuilderScreen> {
  String _type = 'for_time';
  bool _requiresEquipment = false;
  final _timeCap = TextEditingController();
  final _rounds = TextEditingController(text: '1'); // nb de tours (la séance répète les mouvements)
  final List<_Block> _blocks = [];
  List<MovementSummary> _catalog = [];
  EstimateResult? _estimate;
  bool _estimating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref.read(apiClientProvider).movements().then((m) {
      if (mounted) setState(() => _catalog = m);
    });
  }

  @override
  void dispose() {
    _timeCap.dispose();
    _rounds.dispose();
    super.dispose();
  }

  String get _scoreType => _scoreTypeFor(_type);

  /// Nom généré automatiquement : format (For Time, EMOM…) + mouvements clés.
  /// L'utilisateur ne choisit pas le nom — l'app en propose un cohérent.
  String get _generatedName {
    if (_blocks.isEmpty) return AppLocalizations.of(context).wodBuilderCustomWorkout;
    final fmt = _formats[_type] ?? AppLocalizations.of(context).wodBuilderWorkout;
    final seen = <String>{};
    final names = <String>[];
    for (final b in _blocks) {
      if (seen.add(b.movement.name.toLowerCase())) names.add(b.movement.name);
    }
    String part;
    if (names.length == 1) {
      part = names[0];
    } else if (names.length == 2) {
      part = '${names[0]} & ${names[1]}';
    } else if (names.length == 3) {
      part = '${names[0]}, ${names[1]} & ${names[2]}';
    } else {
      part = '${names[0]}, ${names[1]} +${names.length - 2}';
    }
    return '$fmt · $part';
  }

  Map<String, dynamic> _payload({double? userResult}) {
    String amountKey(String unit) =>
        unit == 'meter' ? 'distanceMeters' : unit == 'calorie' ? 'calories' : unit == 'second' ? 'durationSec' : 'reps';
    return {
      'sex': ref.read(sessionProvider).sex ?? 'male',
      'scoreType': _scoreType,
      'wodType': _type,
      if (int.tryParse(_timeCap.text) != null) 'timeCapSec': int.parse(_timeCap.text) * 60,
      if ((int.tryParse(_rounds.text) ?? 1) > 1) 'rounds': int.parse(_rounds.text),
      'blocks': _blocks
          .map((b) => {
                'movementId': b.movement.id,
                amountKey(b.movement.unit): b.amount,
                if (b.loadKg != null) 'loadKg': b.loadKg,
              })
          .toList(),
      if (userResult != null) 'userResult': userResult,
    };
  }

  Future<void> _refreshEstimate() async {
    if (_blocks.isEmpty) {
      setState(() => _estimate = null);
      return;
    }
    setState(() => _estimating = true);
    try {
      final e = await ref.read(apiClientProvider).estimateWod(_payload());
      if (mounted) setState(() => _estimate = e);
    } catch (_) {
      if (mounted) setState(() => _estimate = null);
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  void _addMovement() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HiColors.bgElevated,
      isScrollControlled: true,
      builder: (_) => _MovementSheet(
        catalog: _catalog,
        onPick: (m) {
          Navigator.of(context).pop();
          final defaultAmount = m.unit == 'meter' ? 200 : m.unit == 'calorie' ? 15 : m.unit == 'second' ? 30 : 10;
          setState(() => _blocks.add(_Block(m, defaultAmount, null)));
          _refreshEstimate();
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_blocks.isEmpty) {
      _toast(AppLocalizations.of(context).wodBuilderAddMovementError);
      return;
    }
    final name = _generatedName;
    setState(() => _saving = true);
    try {
      final payload = _payload()
        ..['name'] = name
        ..['requiresEquipment'] = _requiresEquipment;
      payload.remove('sex');
      payload.remove('userResult');
      // L'estimation utilise `wodType` ; la création attend `type` (CreateWodRequest) → on convertit.
      payload['type'] = _type;
      payload.remove('wodType');
      final id = await ref.read(apiClientProvider).createWod(payload);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => WodDetailScreen(wodId: id, wodName: name)),
      );
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.wodBuilderTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HiSpace.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.wodBuilderFormat, style: HiType.caption.copyWith(color: HiColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _formats.entries.map((e) {
                    final active = _type == e.key;
                    return ChoiceChip(
                      label: Text(e.value),
                      selected: active,
                      showCheckmark: false,
                      selectedColor: HiColors.brandPrimary,
                      backgroundColor: HiColors.bgElevated2,
                      labelStyle: TextStyle(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w600),
                      side: BorderSide(color: HiColors.strokeSubtle),
                      onSelected: (_) {
                        setState(() => _type = e.key);
                        _refreshEstimate();
                      },
                    );
                  }).toList(),
                ),
                if (const ['for_time', 'chipper', 'interval'].contains(_type)) ...[
                  const SizedBox(height: HiSpace.md),
                  Row(children: [
                    Text(t.wodBuilderRoundsLabel, style: HiType.body.copyWith(color: HiColors.textSecondary)),
                    SizedBox(
                      width: 64,
                      child: TextField(
                        controller: _rounds,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        onChanged: (_) => _refreshEstimate(),
                        decoration: InputDecoration(hintText: t.wodBuilderRoundsHint, isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t.wodBuilderRoundsCaption,
                          style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                    ),
                  ]),
                ],
                if (_scoreType == 'time') ...[
                  const SizedBox(height: HiSpace.sm),
                  Text(t.wodBuilderTimeNote,
                      style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                ],
                if (_scoreType == 'reps') ...[
                  const SizedBox(height: HiSpace.md),
                  Row(children: [
                    Text(t.wodBuilderCapLabel, style: HiType.body.copyWith(color: HiColors.textSecondary)),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: _timeCap,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => _refreshEstimate(),
                        decoration: InputDecoration(hintText: t.wodBuilderCapHint),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: HiSpace.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: HiColors.brandPrimary,
                  value: _requiresEquipment,
                  title: Text(t.wodBuilderRequiresEquipment, style: HiType.body.copyWith(color: HiColors.textPrimary)),
                  onChanged: (v) => setState(() => _requiresEquipment = v),
                ),
                const SizedBox(height: HiSpace.md),
                Text(t.wodBuilderMovements, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                const SizedBox(height: HiSpace.sm),
                ..._blocks.asMap().entries.map((e) => _blockRow(e.key, e.value)),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: HiColors.strokeStrong),
                    foregroundColor: HiColors.brandPrimary,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(t.wodBuilderAddMovement),
                  onPressed: _catalog.isEmpty ? null : _addMovement,
                ),
                const SizedBox(height: HiSpace.lg),
                _estimateCard(),
                const SizedBox(height: HiSpace.lg),
                _nameCard(),
                const SizedBox(height: HiSpace.md),
                HiButton(label: t.wodBuilderPublish, loading: _saving, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _unitHint(String unit) =>
      unit == 'meter' ? 'ex. 2000' : unit == 'calorie' ? 'ex. 15' : unit == 'second' ? 'ex. 30' : 'ex. 10';
  String _unitSuffix(String unit) =>
      unit == 'meter' ? 'm' : unit == 'calorie' ? 'cal' : unit == 'second' ? 'sec' : 'reps';

  Widget _blockRow(int i, _Block b) {
    final isLoaded = b.movement.category == 'weightlifting';
    return Card(
      margin: const EdgeInsets.only(bottom: HiSpace.sm),
      child: Padding(
        padding: const EdgeInsets.all(HiSpace.md),
        child: Row(
          children: [
            Expanded(child: Text(b.movement.name, style: HiType.body.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w600))),
            SizedBox(
              width: 116,
              child: TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  // Unité visible en permanence (suffixe) → ex. « mètres » pour la course.
                  hintText: _unitHint(b.movement.unit),
                  suffixText: _unitSuffix(b.movement.unit),
                  isDense: true,
                ),
                controller: TextEditingController(text: '${b.amount}'),
                onChanged: (v) {
                  b.amount = int.tryParse(v) ?? b.amount;
                  _refreshEstimate();
                },
              ),
            ),
            if (isLoaded) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 56,
                child: TextField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: 'kg'),
                  onChanged: (v) {
                    b.loadKg = double.tryParse(v);
                    _refreshEstimate();
                  },
                ),
              ),
            ],
            IconButton(
              icon: Icon(Icons.close_rounded, color: HiColors.textTertiary, size: 20),
              onPressed: () {
                setState(() => _blocks.removeAt(i));
                _refreshEstimate();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Aperçu du nom auto-attribué (l'utilisateur ne le saisit pas).
  Widget _nameCard() {
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: HiColors.brandPrimary, size: 20),
          const SizedBox(width: HiSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).wodBuilderAssignedName, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                const SizedBox(height: 2),
                Text(_generatedName, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _estimateCard() {
    final t = AppLocalizations.of(context);
    if (_estimating) {
      return Center(child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: HiColors.brandPrimary))));
    }
    if (_estimate == null) {
      return Text(t.wodBuilderEstimateEmpty, textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textTertiary));
    }
    final e = _estimate!;
    final champ = e.ref('champion')?.rawResult;
    final inter = e.ref('intermediate')?.rawResult;
    final beg = e.ref('occasional')?.rawResult;
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.warn.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(t.wodBuilderEstimate, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: HiColors.warn.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(HiRadius.pill)),
              child: Text(t.wodBuilderEstimated, style: HiType.caption.copyWith(color: HiColors.warn, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: HiSpace.sm),
          if (champ != null) Text(t.wodBuilderEstimateChampion(formatWodResult(champ, _scoreType)), style: HiType.body.copyWith(color: HiColors.textSecondary)),
          if (inter != null) Text(t.wodBuilderEstimateIntermediate(formatWodResult(inter, _scoreType)), style: HiType.body.copyWith(color: HiColors.textSecondary)),
          if (beg != null) Text(t.wodBuilderEstimateBeginner(formatWodResult(beg, _scoreType)), style: HiType.body.copyWith(color: HiColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: e.attributesAffected
                .map((a) => Text('◆ ${HiLabels.attribute(a)}', style: HiType.caption.copyWith(color: HiColors.attribute(a))))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MovementSheet extends StatefulWidget {
  final List<MovementSummary> catalog;
  final ValueChanged<MovementSummary> onPick;
  const _MovementSheet({required this.catalog, required this.onPick});

  @override
  State<_MovementSheet> createState() => _MovementSheetState();
}

class _MovementSheetState extends State<_MovementSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final items = widget.catalog.where((m) => m.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(HiSpace.md),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(hintText: AppLocalizations.of(context).wodBuilderSearchMovement, prefixIcon: const Icon(Icons.search_rounded)),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: HiSpace.sm),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: items.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(items[i].name, style: HiType.body.copyWith(color: HiColors.textPrimary)),
                  subtitle: Text(items[i].category, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                  trailing: Icon(Icons.add_rounded, color: HiColors.brandPrimary),
                  onTap: () => widget.onPick(items[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
