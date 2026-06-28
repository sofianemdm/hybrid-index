import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import '../../widgets/error_retry.dart';
import 'wod_detail_screen.dart';
import 'wod_format.dart';

// Le format « distance » est RETIRÉ du builder : le moteur ne le note pas correctement (la
// distribution dégénère → résultat rejeté/aberrant, audit BUG-005). À réintroduire avec une vraie
// notation par allure/distance. La course se mesure via les WODs de course existants.
const _formats = {
  'for_time': 'For Time',
  'amrap': 'AMRAP',
  'emom': 'EMOM',
  'chipper': 'Chipper',
  'interval': 'Intervalles',
  'tabata': 'Tabata',
  'strength': 'Force',
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
  // Controllers PERSISTANTS (1 par bloc) : créés hors build → le curseur ne saute plus à chaque
  // frappe et la valeur reste affichée (avant : un nouveau controller à chaque rebuild remettait la
  // sélection à 0 et perdait la charge saisie, BUG-004). `loadController` réaffiche la charge kg.
  final TextEditingController controller;
  final TextEditingController loadController;
  _Block(this.movement, this.amount, this.loadKg)
      : controller = TextEditingController(text: '$amount'),
        loadController = TextEditingController(text: loadKg == null ? '' : _fmtKg(loadKg));

  /// Affiche une charge kg sans « .0 » superflu (18.0 → « 18 », 17.5 → « 17.5 »).
  static String _fmtKg(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
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
  bool _estimateError = false; // dernier appel d'estimation a échoué (réseau/serveur)
  bool _saving = false;
  // Debounce : on n'envoie pas un POST par frappe. Le jeton `_estimateSeq` ignore les réponses
  // périmées (course de requêtes) → seule la dernière demande met à jour l'UI.
  Timer? _debounce;
  int _estimateSeq = 0;

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
    for (final b in _blocks) {
      b.controller.dispose();
      b.loadController.dispose();
    }
    _debounce?.cancel();
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

  /// Point d'entrée appelé à chaque modif (frappe, chip, ajout/suppression). DEBOUNCE ~400ms :
  /// on n'envoie la requête qu'après une courte pause de saisie → 1 POST au lieu d'un par frappe.
  void _refreshEstimate() {
    _debounce?.cancel();
    if (_blocks.isEmpty) {
      _estimateSeq++; // invalide toute réponse en vol
      setState(() {
        _estimate = null;
        _estimating = false;
        _estimateError = false;
      });
      return;
    }
    // Feedback immédiat : on montre l'état « calcul » sans attendre la fin du debounce.
    if (!_estimating) setState(() => _estimating = true);
    _debounce = Timer(const Duration(milliseconds: 400), _runEstimate);
  }

  Future<void> _runEstimate() async {
    final seq = ++_estimateSeq; // jeton de CETTE requête
    if (mounted && (!_estimating || _estimateError)) {
      setState(() {
        _estimating = true;
        _estimateError = false;
      });
    }
    try {
      final e = await ref.read(apiClientProvider).estimateWod(_payload());
      if (!mounted || seq != _estimateSeq) return; // réponse périmée → on l'ignore
      setState(() {
        _estimate = e;
        _estimateError = false;
        _estimating = false;
      });
    } catch (_) {
      if (!mounted || seq != _estimateSeq) return;
      // Erreur réseau : on NE détruit PAS une estimation déjà valide, on signale juste l'échec.
      setState(() {
        _estimateError = true;
        _estimating = false;
      });
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
            // a11y : champ sans libellé visible (juste un suffixe d'unité) → on nomme l'objet saisi.
            Semantics(
              textField: true,
              label: AppLocalizations.of(context).a11yAmountField(b.movement.name, _unitSuffix(b.movement.unit)),
              child: SizedBox(
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
                  controller: b.controller,
                  onChanged: (v) {
                    b.amount = int.tryParse(v) ?? b.amount;
                    _refreshEstimate();
                  },
                ),
              ),
            ),
            if (isLoaded) ...[
              const SizedBox(width: 6),
              Semantics(
                textField: true,
                label: AppLocalizations.of(context).a11yLoadField(b.movement.name),
                child: SizedBox(
                width: 64,
                child: TextField(
                  controller: b.loadController,
                  // Charge décimale : on accepte virgule ET point (clavier FR/EN), un seul séparateur.
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: 'kg', isDense: true),
                  onChanged: (v) {
                    // Normalise la virgule en point pour le parse (12,5 → 12.5).
                    b.loadKg = double.tryParse(v.replaceAll(',', '.'));
                    _refreshEstimate();
                  },
                ),
              ),
              ),
            ],
            IconButton(
              tooltip: AppLocalizations.of(context).a11yRemoveMovementNamed(b.movement.name),
              icon: Icon(Icons.close_rounded, color: HiColors.textTertiary, size: 20),
              onPressed: () {
                setState(() {
                  final removed = _blocks.removeAt(i);
                  removed.controller.dispose();
                  removed.loadController.dispose();
                });
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
    // Erreur réseau SANS estimation valide en mémoire → encart d'erreur compact + « Réessayer »
    // (on ne montre l'erreur pleine que si on n'a rien d'autre à afficher).
    if (_estimateError && _estimate == null) {
      return ErrorRetry(
        compact: true,
        message: t.wodBuilderEstimateError,
        onRetry: _runEstimate,
      );
    }
    if (_estimating && _estimate == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: HiColors.brandPrimary))));
    }
    if (_estimate == null) {
      return Text(t.wodBuilderEstimateEmpty, textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textTertiary));
    }
    final e = _estimate!;
    // Format non estimable de façon fiable (ex. charge sans mouvement chargé) : message explicite,
    // jamais de « 0 kg ». Cf. §A « Création de séance AAA ».
    if (e.notEstimable) {
      return Container(
        padding: const EdgeInsets.all(HiSpace.md),
        decoration: BoxDecoration(
          color: HiColors.bgElevated,
          borderRadius: BorderRadius.circular(HiRadius.md),
          border: Border.all(color: HiColors.strokeSubtle),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: HiColors.textTertiary, size: 20),
            const SizedBox(width: HiSpace.sm),
            Expanded(
              child: Text(t.wodBuilderEstimateUnavailable,
                  style: HiType.body.copyWith(color: HiColors.textSecondary)),
            ),
          ],
        ),
      );
    }
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
            if (_estimating)
              ExcludeSemantics(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: HiColors.brandPrimary)))
            else
              Semantics(
                label: t.a11yEstimateBadge,
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: HiColors.warn.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(HiRadius.pill)),
                    child: Text(t.wodBuilderEstimated, style: HiType.caption.copyWith(color: HiColors.warn, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ]),
          // Estimation valide mais le dernier rafraîchissement a échoué → on garde l'ancienne
          // valeur (pas d'écrasement) et on propose un re-essai discret.
          if (_estimateError) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.cloud_off_rounded, size: 14, color: HiColors.error),
              const SizedBox(width: 6),
              Expanded(child: Text(t.wodBuilderEstimateError, style: HiType.caption.copyWith(color: HiColors.error))),
              TextButton(
                onPressed: _runEstimate,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
                child: Text(t.commonRetry, style: HiType.caption.copyWith(color: HiColors.brandPrimary, fontWeight: FontWeight.w600)),
              ),
            ]),
          ],
          const SizedBox(height: HiSpace.sm),
          // a11y : les 3 paliers d'estimation (champion/intermédiaire/débutant) lus comme un groupe.
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (champ != null) Text(t.wodBuilderEstimateChampion(formatWodResult(champ, _scoreType)), style: HiType.body.copyWith(color: HiColors.textSecondary)),
                if (inter != null) Text(t.wodBuilderEstimateIntermediate(formatWodResult(inter, _scoreType)), style: HiType.body.copyWith(color: HiColors.textSecondary)),
                if (beg != null) Text(t.wodBuilderEstimateBeginner(formatWodResult(beg, _scoreType)), style: HiType.body.copyWith(color: HiColors.textSecondary)),
              ],
            ),
          ),
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
