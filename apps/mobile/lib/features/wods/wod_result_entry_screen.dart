import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/analytics.dart';
import '../../data/api_client.dart';
import '../../data/outbox.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/ui_state.dart';
import '../../data/review_prompt.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/celebration.dart';
import 'wod_format.dart';
import 'result_feedback.dart';
import '../../widgets/hi_button.dart';
import '../share/share_card_screen.dart';
import '../progression/progression_screen.dart';

/// Saisie d'un résultat sur une séance (officiel ou custom) — note via le moteur si custom.
class WodResultEntryScreen extends ConsumerStatefulWidget {
  final String wodId;
  final String wodName;
  final String scoreType;

  /// La séance a-t-elle une échelle Rx/Allégé ? UNIQUE source = la prescription du back (poids
  /// non vide), passée par l'appelant (fiche WOD). Défaut false (custom / poids du corps / cardio).
  final bool scalable;

  /// Temps d'effort réalisé au Mode guidé (HORS décompte 3·2·1), à PRÉ-REMPLIR dans la saisie.
  /// Pris en compte UNIQUEMENT pour un WOD `scoreType == 'time'` (le chrono ne représente pas le
  /// score d'un AMRAP/charge/reps). `null` = saisie manuelle → champs vides (comportement inchangé).
  /// L'utilisateur peut toujours modifier la valeur pré-remplie avant de valider.
  final Duration? prefill;
  const WodResultEntryScreen({
    super.key,
    required this.wodId,
    required this.wodName,
    required this.scoreType,
    this.scalable = false,
    this.prefill,
  });

  @override
  ConsumerState<WodResultEntryScreen> createState() => _WodResultEntryScreenState();
}

class _WodResultEntryScreenState extends ConsumerState<WodResultEntryScreen> {
  final _value = TextEditingController();
  final _distance = TextEditingController(); // mètres — course à distance libre uniquement
  final _min = TextEditingController();
  final _sec = TextEditingController();
  bool _rx = true;
  bool _loading = false;
  // Clé d'idempotence STABLE pour cette saisie : un double-tap ou un retry réseau réutilise la même
  // clé → le serveur dédoublonne (pas de double comptage, audit BUG-014).
  final String _idempotencyKey = 'log-${DateTime.now().microsecondsSinceEpoch}-${UniqueKey()}';
  /// Copie du payload construit dans le try — accessible du catch (mise en file OUTBOX hors ligne).
  Map<String, dynamic>? _payloadForOutbox;

  bool get _isTime => widget.scoreType == 'time';
  bool get _isFreeRun => widget.wodId == 'run_free_distance';
  // HYROX (solo) se court en catégorie Pro ou Open (poids/obstacles différents) → on mappe
  // Pro = "prescrit" (rxCompliant true) et Open = "adapté" (false), classements séparés.
  bool get _isHyrox => widget.wodId == 'hyrox_solo';
  // L'échelle Rx/Scaled n'a de sens que pour les WODs à CHARGE (barre/haltère/KB/wall ball).
  // Source UNIQUE : la prescription du back (poids non vide) exposée via `widget.scalable`.
  // Plus de liste codée en dur ici — la fiche WOD et l'entrée de résultat partagent la même vérité.
  bool get _hasScale => widget.scalable;

  @override
  void initState() {
    super.initState();
    if (_isHyrox) _rx = false; // défaut HYROX : Open (catégorie la plus courante).
    // Pré-remplissage depuis le Mode guidé : uniquement pour un WOD chrono (`time`). Pour les autres
    // scoreType (reps/charge/AMRAP), le chrono ne représente pas le score → on laisse les champs vides.
    final prefill = widget.prefill;
    if (prefill != null && _isTime) {
      final totalSec = prefill.inSeconds;
      _min.text = (totalSec ~/ 60).toString();
      _sec.text = (totalSec % 60).toString().padLeft(2, '0'); // secondes sur 2 chiffres (ex. 3min02 → '02')
    }
  }

  @override
  void dispose() {
    _value.dispose();
    _min.dispose();
    _sec.dispose();
    _distance.dispose();
    super.dispose();
  }

  double? get _raw {
    if (_isTime) {
      final t = (int.tryParse(_min.text) ?? 0) * 60 + (int.tryParse(_sec.text) ?? 0);
      return t > 0 ? t.toDouble() : null;
    }
    final v = double.tryParse(_value.text.replaceAll(',', '.'));
    return (v != null && v > 0) ? v : null;
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context); // capturé avant tout await (pas de context post-async)
    // Les secondes doivent rester dans [0,59] (sinon « 4:90 » serait enregistré comme 5:30, BUG-013).
    if (_isTime) {
      final sec = int.tryParse(_sec.text) ?? 0;
      if (sec > 59) {
        _toast(t.wreSecondsRange);
        return;
      }
    }
    final raw = _raw;
    if (raw == null) {
      _toast(t.wreInvalidResult);
      return;
    }
    int? distanceMeters;
    if (_isFreeRun) {
      distanceMeters = int.tryParse(_distance.text.trim());
      if (distanceMeters == null || distanceMeters <= 0) {
        _toast(t.wreNeedDistance);
        return;
      }
    }
    setState(() => _loading = true);
    try {
      // Prédiction AVANT d'enregistrer : on compare la perf au niveau d'AVANT ce résultat (sinon le
      // log mettrait à jour le niveau et fausserait la comparaison). Best-effort ; null = pas d'estim.
      num? predictedBefore;
      String predScoreType = widget.scoreType;
      try {
        final pred = await ref.read(apiClientProvider).wodPrediction(widget.wodId);
        predictedBefore = pred?.predictedRaw;
        predScoreType = pred?.scoreType ?? widget.scoreType;
      } catch (_) {/* prédiction indispo → message neutre */}

      final payload = _payloadForOutbox = <String, dynamic>{
        'rawResult': raw,
        'rxCompliant': _rx,
        'idempotencyKey': _idempotencyKey,
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
      };
      final logRes = await ref.read(apiClientProvider).logWodResult(widget.wodId, payload);
      final profile = logRes.profile;
      Analytics.capture('wod_logged', {'wodId': widget.wodId, 'index': profile?.index.value});
      ref.invalidate(myProfileProvider);
      ref.invalidate(completionPlanProvider); // un attribut vient peut-être d'être débloqué
      ref.invalidate(streakProvider); // la semaine vient peut-être d'être validée
      ref.invalidate(weeklyRecapProvider);
      if (!mounted) return;
      if (profile != null) {
        final bandText = _bandUpText(profile.bandCelebration);
        final hasGains = profile.gains.isNotEmpty;
        if (bandText != null) {
          // Montée de bande population → célébration FORTE (le moment dopamine maximal) + partage.
          await Celebration.show(
            context,
            value: '${profile.index.value}',
            title: bandText,
            subtitle: hasGains ? _gainsLine(profile.gains) : AppLocalizations.of(context).wreIndexClimbs,
            intensity: CelebrationIntensity.strong,
            actionLabel: AppLocalizations.of(context).wreShareFeat,
            onAction: () {
              if (mounted) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShareCardScreen()));
              }
            },
          );
        } else {
          // Message MOTIVANT : compare la perf au temps/score PRÉDIT pour l'utilisateur (5 paliers,
          // ton scientifique/encourageant). Plein écran si on bat/atteint la cible ; dialogue calme si
          // en dessous (jamais de fanfare sur une contre-perf) ; encouragement neutre si pas de prédiction.
          await ResultFeedback.from(
            loc: t,
            actual: raw,
            predicted: predictedBefore,
            scoreType: predScoreType,
            wodName: widget.wodName,
          ).show(context);
        }
        // Moment de réussite (PR / montée de bande) → demande d'avis natif (OS-plafonné, no-op web).
        if (hasGains || profile.bandCelebration != null) {
          maybeAskForReview();
        }
        // Lever #1 (cahier §4.3) : l'auteur vient de DOUBLER un ou plusieurs athlètes au classement
        // → célébration « Tu as doublé X ! » + « Nouveau rival en vue ». UNE seule fois : le flag
        // n'est présent que dans CETTE réponse de log (jamais sur un GET), donc pas de répétition au
        // rebuild. Enchaîne après le message de résultat ; Celebration rétrograde déjà une 2e « forte ».
        if (mounted) {
          await _celebrateOvertake(profile.overtook);
        }
        // Célébration de badge : ENCHAÎNE après le message de résultat (et après une éventuelle montée
        // de bande). On ne double pas une « forte » : Celebration.show rétrograde déjà la 2e en moyenne.
        if (mounted) {
          await _celebrateBadges(logRes.unlockedBadges);
        }
      }
      // Après l'enregistrement : on bascule sur l'accueil (onglet 0) et on dépile jusqu'à la racine.
      // CONTRAT : cet écran est AUTO-SUFFISANT pour rafraîchir l'accueil — toutes les invalidations
      // utiles (profil, plan, série, récap) sont déjà faites ci-dessus AVANT de dépiler. Le `await`
      // du FAB se résout donc à null (route dépilée), ce qui est volontaire. ATTENTION : tout point
      // d'entrée qui logge un résultat sera renvoyé à l'accueil (comportement voulu aujourd'hui).
      if (mounted) {
        ref.read(homeTabProvider.notifier).state = 0;
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on ApiException catch (e) {
      // HORS LIGNE → le résultat part dans l'OUTBOX (rejoué automatiquement au retour du réseau,
      // même idempotencyKey = zéro doublon). Le score sera calculé à la synchro (heure serveur).
      if (e.code == 'NETWORK' || e.code == 'TIMEOUT') {
        await Outbox(ref.read(apiClientProvider)).enqueue(widget.wodId, _payloadForOutbox!);
        if (mounted) {
          _toast(t.outboxQueued);
          ref.read(homeTabProvider.notifier).state = 0;
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
        return;
      }
      _toast(e.code == 'WOD_RESULT_OUT_OF_BOUNDS' ? t.wreOutOfBounds : e.message);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Résumé des gains d'attributs (« Engine +3 · Force +2 »).
  String _gainsLine(List<AttributeGain> gains) {
    if (gains.isEmpty) return AppLocalizations.of(context).wreIndexClimbs;
    return gains.map((g) => '${HiLabels.attribute(g.attribute)} +${g.delta}').join(' · ');
  }

  /// Message de célébration quand on monte de bande population (« pop_top_3 » → « top 3% »).
  String? _bandUpText(List<String>? celebration) {
    if (celebration == null || celebration.length < 2) return null;
    final to = celebration[1];
    final m = RegExp(r'pop_top_(\d+)').firstMatch(to);
    if (m == null) return null;
    return AppLocalizations.of(context).wreBandUp(int.parse(m.group(1)!));
  }

  /// Intensité de la célébration selon la rareté du badge le plus rare débloqué.
  CelebrationIntensity _intensityForRarity(String rarity) {
    switch (rarity) {
      case 'legendary':
      case 'epic':
        return CelebrationIntensity.strong;
      case 'rare':
        return CelebrationIntensity.medium;
      default:
        return CelebrationIntensity.light;
    }
  }

  static const _rarityRank = {'common': 0, 'rare': 1, 'epic': 2, 'legendary': 3};

  /// Célèbre les badges débloqués par ce log : une seule fenêtre, calibrée sur le badge le plus
  /// rare, avec un CTA « Voir mes badges » qui ouvre la Progression. No-op si aucun badge.
  Future<void> _celebrateBadges(List<BadgeModel> badges) async {
    if (badges.isEmpty || !mounted) return;
    final t = AppLocalizations.of(context);
    // Le badge le plus rare porte la célébration (les autres sont cités en sous-titre).
    final best = badges.reduce(
      (a, b) => (_rarityRank[b.rarity] ?? 0) > (_rarityRank[a.rarity] ?? 0) ? b : a,
    );
    final others = badges.where((x) => x.id != best.id).toList();
    final subtitle = others.isEmpty
        ? best.description
        : '${best.description}\n+${others.length} autre${others.length > 1 ? 's' : ''} badge${others.length > 1 ? 's' : ''}';
    await Celebration.show(
      context,
      icon: Icons.military_tech_rounded,
      title: badges.length > 1 ? t.wreBadgesUnlocked(badges.length) : t.wreBadgeUnlocked(best.name),
      subtitle: subtitle,
      accent: HiColors.accentVictory,
      intensity: _intensityForRarity(best.rarity),
      actionLabel: t.wreSeeMyBadges,
      onAction: () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(t.navProgress), backgroundColor: Colors.transparent, elevation: 0),
              body: const ProgressionScreen(),
            ),
          ),
        );
      },
    );
  }

  /// Lever #1 (cahier §4.3) : célèbre l'auteur qui vient de DOUBLER un athlète au classement de sa
  /// ligue. Titre « Tu as doublé X ! », sous-titre « Nouveau rival en vue ». No-op si pas de
  /// dépassement (flag absent) ou pseudo vide. Intensité FORTE (moment dopamine du lever).
  Future<void> _celebrateOvertake(Overtook? overtook) async {
    if (overtook == null || overtook.topName.isEmpty || !mounted) return;
    final t = AppLocalizations.of(context);
    await Celebration.show(
      context,
      icon: Icons.trending_up_rounded,
      title: t.wreOvertookTitle(overtook.topName),
      subtitle: t.wreOvertookSubtitle,
      accent: HiColors.accentVictory,
      intensity: CelebrationIntensity.strong,
    );
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final pref = ref.watch(sessionProvider).sex;
    return Scaffold(
      appBar: AppBar(title: Text(widget.wodName), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HiSpace.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isFreeRun) ...[
                  Text(t.wreDistanceLabel, style: HiType.body.copyWith(color: HiColors.textSecondary)),
                  const SizedBox(height: 8),
                  _num(_distance, t.wreDistanceHint),
                  const SizedBox(height: HiSpace.lg),
                ],
                Text(_isFreeRun
                    ? t.wreYourTime
                    : t.wreYourResult(_isTime ? t.wreUnitTime : wodUnitLabel(widget.wodId, widget.scoreType, roundsLabel: t.wodFormatRounds)),
                    style: HiType.body.copyWith(color: HiColors.textSecondary)),
                const SizedBox(height: 8),
                if (_isTime)
                  Row(children: [
                    Expanded(child: _num(_min, 'min')),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(':', style: HiType.numericM.copyWith(color: HiColors.textSecondary))),
                    Expanded(child: _num(_sec, 'sec')),
                  ])
                else
                  _num(_value, t.wreResultHint, decimal: widget.scoreType == 'load'),
                // Échelle Rx/Scaled : uniquement pour les WODs à charge ; Pro/Open pour HYROX solo.
                if (_isHyrox || _hasScale) ...[
                  const SizedBox(height: HiSpace.lg),
                  Text(_isHyrox ? t.wreCategory : t.wreScale, style: HiType.body.copyWith(color: HiColors.textSecondary)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _scaleChip(_isHyrox ? t.wrePro : t.wreRx, true),
                    const SizedBox(width: 8),
                    _scaleChip(_isHyrox ? t.wreOpen : t.wreScaled, false),
                  ]),
                  if (_isHyrox || pref != null) ...[
                    const SizedBox(height: HiSpace.sm),
                    Text(_isHyrox ? t.wreSeparatedPro : t.wreSeparatedRx,
                        style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                  ],
                ],
                const SizedBox(height: HiSpace.xl),
                HiButton(label: t.wreSave, loading: _loading, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scaleChip(String label, bool rx) {
    final active = _rx == rx;
    // a11y : chip d'option annoncée (bouton sélectionné/non) ; cible tactile ≥ 48dp.
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: () => setState(() => _rx = rx),
            child: Container(
              constraints: const BoxConstraints(minHeight: HiTap.minTarget),
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: active ? HiColors.brandGradient : null,
                color: active ? null : HiColors.bgElevated2,
                borderRadius: BorderRadius.circular(HiRadius.pill),
              ),
              child: Text(label,
                  style: HiType.body
                      .copyWith(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _num(TextEditingController c, String hint, {bool decimal = false}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: decimal ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : [FilteringTextInputFormatter.digitsOnly],
      textAlign: _isTime ? TextAlign.center : TextAlign.start,
      decoration: InputDecoration(hintText: hint),
    );
  }
}
