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
// Ordre d'affichage des formats. Les libellés sont localisés via [_formatLabel] (i18n FR+EN) :
// « Intervalles »/« Force » ne doivent plus s'afficher en français en locale EN.
const _formatKeys = ['for_time', 'amrap', 'emom', 'chipper', 'interval', 'tabata', 'strength'];

String _formatLabel(AppLocalizations t, String key) {
  switch (key) {
    case 'for_time':
      return t.wodFmtForTime;
    case 'amrap':
      return t.wodFmtAmrap;
    case 'emom':
      return t.wodFmtEmom;
    case 'chipper':
      return t.wodFmtChipper;
    case 'interval':
      return t.wodFmtInterval;
    case 'tabata':
      return t.wodFmtTabata;
    case 'strength':
      return t.wodFmtStrength;
    default:
      return t.wodBuilderWorkout;
  }
}

String _scoreTypeFor(String wodType) {
  switch (wodType) {
    case 'amrap':
    case 'emom':
    case 'tabata':
      return 'reps';
    case 'strength':
      return 'load';
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
/// En mode ÉDITION (`editWodId` + `prefill` fournis), le formulaire est pré-rempli et la
/// publication appelle PATCH au lieu de POST (seul le créateur peut éditer, garanti côté back).
class WodBuilderScreen extends ConsumerStatefulWidget {
  /// Id du WOD à éditer (mode édition). Null → création d'un nouveau WOD.
  final String? editWodId;

  /// Données pré-remplissant le constructeur en mode édition.
  final WodEditPayload? prefill;

  const WodBuilderScreen({super.key, this.editWodId, this.prefill});

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
  bool _catalogLoading = true; // chargement initial du catalogue de mouvements
  bool _catalogError = false; // échec de chargement → on affiche un état d'erreur + réessayer
  // Nom de séance : pré-rempli avec le nom auto, mais ÉDITABLE. Tant que l'utilisateur n'a pas
  // touché le champ, on suit le nom auto-généré ; dès qu'il édite, on respecte sa saisie.
  final _name = TextEditingController();
  bool _nameEdited = false;
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
    final p = widget.prefill;
    if (p != null) {
      // Mode édition : on pré-remplit les champs hors blocs immédiatement. Les blocs (qui dépendent
      // du catalogue de mouvements) sont reconstitués après son chargement (cf. _loadCatalog).
      _type = p.type;
      _requiresEquipment = p.requiresEquipment;
      if (p.timeCapSec != null) _timeCap.text = '${(p.timeCapSec! / 60).round()}';
      if (p.rounds != null && p.rounds! > 1) _rounds.text = '${p.rounds}';
      _name.text = p.name;
      _nameEdited = true; // le nom existant fait foi (on ne le réécrase pas avec le nom auto)
    }
    _loadCatalog();
  }

  /// Reconstitue les blocs à partir du payload d'édition, une fois le catalogue chargé : on associe
  /// chaque `movementId` enregistré à son [MovementSummary] et on relit la quantité selon son unité.
  void _hydrateBlocksFromPrefill() {
    final p = widget.prefill;
    if (p == null || _blocks.isNotEmpty) return;
    final byId = {for (final m in _catalog) m.id: m};
    for (final raw in p.blocks) {
      final m = byId[raw['movementId'] as String?];
      if (m == null) continue; // mouvement retiré du catalogue → on l'ignore proprement
      final amount = (raw['reps'] ?? raw['distanceMeters'] ?? raw['calories'] ?? raw['durationSec'] ?? 0) as num;
      final loadKg = (raw['loadKg'] as num?)?.toDouble();
      _blocks.add(_Block(m, amount.toInt(), loadKg));
    }
    if (_blocks.isNotEmpty) _refreshEstimate();
  }

  /// Charge le catalogue de mouvements. En cas d'échec réseau, on EXPOSE l'erreur (état + retry)
  /// au lieu de laisser le bouton « Ajouter un mouvement » désactivé à vie sans explication.
  Future<void> _loadCatalog() async {
    if (mounted) {
      setState(() {
        _catalogLoading = true;
        _catalogError = false;
      });
    }
    try {
      final m = await ref.read(apiClientProvider).movements();
      if (!mounted) return;
      setState(() {
        _catalog = m;
        _catalogLoading = false;
        _catalogError = false;
        _hydrateBlocksFromPrefill(); // mode édition : reconstitue les blocs depuis le payload
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catalogLoading = false;
        _catalogError = true;
      });
    }
  }

  @override
  void dispose() {
    _timeCap.dispose();
    _rounds.dispose();
    _name.dispose();
    for (final b in _blocks) {
      b.controller.dispose();
      b.loadController.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  String get _scoreType => _scoreTypeFor(_type);

  /// Le DTO back limite `name` à 60 caractères → on tronque côté client (sécurité : un nom auto
  /// avec beaucoup de mouvements pouvait dépasser et faire échouer la création).
  static const int _nameMaxLength = 60;
  String _clampName(String s) => s.length > _nameMaxLength ? s.substring(0, _nameMaxLength) : s;

  /// Nom généré automatiquement : format (For Time, EMOM…) + mouvements clés.
  /// L'app PROPOSE ce nom (pré-rempli) mais l'utilisateur peut le surcharger.
  String get _generatedName {
    if (_blocks.isEmpty) return AppLocalizations.of(context).wodBuilderCustomWorkout;
    final fmt = _formatLabel(AppLocalizations.of(context), _type);
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
    return _clampName('$fmt · $part');
  }

  /// Nom effectif à enregistrer : la saisie utilisateur si elle existe, sinon le nom auto.
  String get _effectiveName {
    final typed = _name.text.trim();
    if (_nameEdited && typed.isNotEmpty) return _clampName(typed);
    return _generatedName;
  }

  /// Synchronise le champ avec le nom auto tant que l'utilisateur n'a rien tapé.
  void _syncAutoName() {
    if (_nameEdited) return;
    final auto = _generatedName;
    if (_name.text != auto) _name.text = auto;
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
    _syncAutoName(); // garde le champ nom aligné sur le nom auto tant qu'on n'a pas édité
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
    final name = _effectiveName;
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
      final editId = widget.editWodId;
      final id = editId != null
          ? await ref.read(apiClientProvider).updateWod(editId, payload)
          : await ref.read(apiClientProvider).createWod(payload);
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

  /// Confirme l'abandon si des mouvements ont été saisis (sinon rien à perdre → on quitte direct).
  /// Retourne true s'il faut effectivement quitter.
  Future<bool> _confirmDiscard() async {
    if (_blocks.isEmpty) return true;
    final t = AppLocalizations.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HiColors.bgElevated,
        title: Text(t.wodBuilderDiscardTitle, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
        content: Text(t.wodBuilderDiscardBody, style: HiType.body.copyWith(color: HiColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.wodBuilderDiscardStay, style: TextStyle(color: HiColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.wodBuilderDiscardLeave, style: TextStyle(color: HiColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PopScope(
      // Garde de sortie : on intercepte le retour pour demander confirmation si la séance contient
      // des blocs non publiés (sinon on perdait tout sans prévenir).
      canPop: _blocks.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.editWodId != null ? t.wodBuilderEditTitle : t.wodBuilderTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
                  children: _formatKeys.map((key) {
                    final active = _type == key;
                    return ChoiceChip(
                      label: Text(_formatLabel(t, key)),
                      selected: active,
                      showCheckmark: false,
                      selectedColor: HiColors.brandPrimary,
                      backgroundColor: HiColors.bgElevated2,
                      labelStyle: TextStyle(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w600),
                      side: BorderSide(color: HiColors.strokeSubtle),
                      onSelected: (_) {
                        setState(() => _type = key);
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
                _addMovementArea(t),
                const SizedBox(height: HiSpace.lg),
                // a11y : l'estimation se met à jour en arrière-plan (debounce/réseau) → liveRegion
                // pour que le lecteur d'écran annonce le nouvel encart sans action de l'utilisateur.
                Semantics(
                  liveRegion: true,
                  label: t.a11yEstimateLiveRegion,
                  container: true,
                  child: _estimateCard(),
                ),
                const SizedBox(height: HiSpace.lg),
                _nameCard(),
                const SizedBox(height: HiSpace.md),
                HiButton(
                  label: widget.editWodId != null ? t.wodBuilderSaveChanges : t.wodBuilderPublish,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// Zone « ajouter un mouvement » : gère chargement / erreur+retry / catalogue prêt.
  Widget _addMovementArea(AppLocalizations t) {
    if (_catalogLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: HiSpace.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: HiColors.brandPrimary)),
            const SizedBox(width: HiSpace.sm),
            Text(t.wodBuilderCatalogLoading, style: HiType.body.copyWith(color: HiColors.textTertiary)),
          ],
        ),
      );
    }
    if (_catalogError || _catalog.isEmpty) {
      // Échec de chargement (ou catalogue vide) : on l'EXPOSE avec un retry au lieu d'un bouton
      // désactivé silencieux.
      return ErrorRetry(
        compact: true,
        message: t.wodBuilderCatalogError,
        onRetry: _loadCatalog,
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: HiColors.strokeStrong),
        foregroundColor: HiColors.brandPrimary,
      ),
      icon: const Icon(Icons.add_rounded),
      label: Text(t.wodBuilderAddMovement),
      onPressed: _addMovement,
    );
  }

  String _unitHint(String unit) {
    final t = AppLocalizations.of(context);
    return unit == 'meter'
        ? t.wodUnitHintMeter
        : unit == 'calorie'
            ? t.wodUnitHintCalorie
            : unit == 'second'
                ? t.wodUnitHintSecond
                : t.wodUnitHintRep;
  }

  String _unitSuffix(String unit) {
    final t = AppLocalizations.of(context);
    return unit == 'meter'
        ? t.wodUnitSuffixMeter
        : unit == 'calorie'
            ? t.wodUnitSuffixCalorie
            : unit == 'second'
                ? t.wodUnitSuffixSecond
                : t.wodUnitSuffixRep;
  }

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
                  decoration: InputDecoration(hintText: AppLocalizations.of(context).wodUnitSuffixKg, isDense: true),
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

  /// Nom de la séance : pré-rempli avec le nom auto, mais ÉDITABLE. L'utilisateur peut surcharger.
  /// Champ borné à 60 caractères (limite du DTO back).
  Widget _nameCard() {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Icon(Icons.auto_awesome_rounded, color: HiColors.brandPrimary, size: 20),
          ),
          const SizedBox(width: HiSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.wodBuilderNameLabel, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                const SizedBox(height: 2),
                TextField(
                  controller: _name,
                  maxLength: _nameMaxLength,
                  textInputAction: TextInputAction.done,
                  style: HiType.titleM.copyWith(color: HiColors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '', // on borne via maxLength sans afficher le compteur
                    hintText: t.wodBuilderNameHint,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) {
                    // Dès la première frappe, on respecte la saisie utilisateur (champ libre vidé inclus).
                    setState(() => _nameEdited = true);
                  },
                ),
                Text(t.wodBuilderNameAutoHint, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
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
