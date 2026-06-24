import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/analytics.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/ui_state.dart';
import '../../data/review_prompt.dart';
import '../../theme/tokens.dart';
import '../../widgets/attribute_gains.dart';
import '../../widgets/celebration.dart';
import 'wod_format.dart';
import '../../widgets/hi_button.dart';
import '../share/share_card_screen.dart';

/// Saisie d'un résultat sur une séance (officiel ou custom) — note via le moteur si custom.
class WodResultEntryScreen extends ConsumerStatefulWidget {
  final String wodId;
  final String wodName;
  final String scoreType;
  const WodResultEntryScreen({super.key, required this.wodId, required this.wodName, required this.scoreType});

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

  bool get _isTime => widget.scoreType == 'time';
  bool get _isFreeRun => widget.wodId == 'run_free_distance';
  // HYROX (solo) se court en catégorie Pro ou Open (poids/obstacles différents) → on mappe
  // Pro = "prescrit" (rxCompliant true) et Open = "adapté" (false), classements séparés.
  bool get _isHyrox => widget.wodId == 'hyrox_solo';
  // L'échelle Rx/Scaled n'a de sens que pour les WODs à CHARGE (barre/haltère/KB/wall ball).
  // Les épreuves cardio (course, rameur) et au poids du corps (pompes, squats, burpees, Cindy,
  // Benchmark Zéro, Machine & Mur…) n'ont rien à « scaler » → on masque l'échelle.
  static const _scaleWods = {
    'fran', 'grace', 'jackie', 'karen', 'helen', 'hyrox_sprint', 'isabel', 'murph',
  };
  bool get _hasScale => _scaleWods.contains(widget.wodId);

  @override
  void initState() {
    super.initState();
    if (_isHyrox) _rx = false; // défaut HYROX : Open (catégorie la plus courante).
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
    final raw = _raw;
    if (raw == null) {
      _toast('Saisis un résultat valide.');
      return;
    }
    int? distanceMeters;
    if (_isFreeRun) {
      distanceMeters = int.tryParse(_distance.text.trim());
      if (distanceMeters == null || distanceMeters <= 0) {
        _toast('Saisis la distance parcourue (en mètres).');
        return;
      }
    }
    setState(() => _loading = true);
    try {
      final payload = <String, dynamic>{
        'rawResult': raw,
        'rxCompliant': _rx,
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
      };
      final profile = await ref.read(apiClientProvider).logWodResult(widget.wodId, payload);
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
            subtitle: hasGains ? _gainsLine(profile.gains) : 'Ton HYBRID INDEX grimpe.',
            intensity: CelebrationIntensity.strong,
            actionLabel: 'Partager mon exploit',
            onAction: () {
              if (mounted) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShareCardScreen()));
              }
            },
          );
        } else if (hasGains) {
          // Progression d'un ou plusieurs axes → célébration MOYENNE.
          await Celebration.show(
            context,
            value: '${profile.index.value}',
            title: 'Tu progresses 💪',
            subtitle: _gainsLine(profile.gains),
            intensity: CelebrationIntensity.medium,
          );
        } else {
          // Aucun gain (no-drop) → retour léger + détail discret.
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: HiColors.bgElevated,
              title: Text('Résultat enregistré 💪', style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('HYBRID INDEX', style: HiType.overline.copyWith(color: HiColors.textSecondary)),
                const SizedBox(height: 8),
                Text('${profile.index.value}', style: HiType.displayL.copyWith(color: HiColors.brandPrimary)),
                const SizedBox(height: 12),
                AttributeGains(gains: profile.gains, weakest: profile.weakest),
              ]),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Continuer'))],
            ),
          );
        }
        // Moment de réussite (PR / montée de bande) → demande d'avis natif (OS-plafonné, no-op web).
        if (hasGains || profile.bandCelebration != null) {
          maybeAskForReview();
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
      _toast(e.code == 'WOD_RESULT_OUT_OF_BOUNDS' ? 'Résultat hors des bornes plausibles.' : e.message);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Résumé des gains d'attributs (« Engine +3 · Force +2 »).
  String _gainsLine(List<AttributeGain> gains) {
    if (gains.isEmpty) return 'Ton HYBRID INDEX grimpe.';
    return gains.map((g) => '${HiLabels.attribute(g.attribute)} +${g.delta}').join(' · ');
  }

  /// Message de célébration quand on monte de bande population (« pop_top_3 » → « top 3% »).
  String? _bandUpText(List<String>? celebration) {
    if (celebration == null || celebration.length < 2) return null;
    final to = celebration[1];
    final m = RegExp(r'pop_top_(\d+)').firstMatch(to);
    if (m == null) return null;
    return '🚀 Tu entres dans le top ${m.group(1)}% des plus en forme !';
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
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
                  Text('Distance parcourue (mètres)', style: HiType.body.copyWith(color: HiColors.textSecondary)),
                  const SizedBox(height: 8),
                  _num(_distance, 'ex. 5000'),
                  const SizedBox(height: HiSpace.lg),
                ],
                Text(_isFreeRun
                    ? 'Ton temps'
                    : 'Ton résultat (${_isTime ? 'temps' : wodUnitLabel(widget.wodId, widget.scoreType)})',
                    style: HiType.body.copyWith(color: HiColors.textSecondary)),
                const SizedBox(height: 8),
                if (_isTime)
                  Row(children: [
                    Expanded(child: _num(_min, 'min')),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(':', style: HiType.numericM.copyWith(color: HiColors.textSecondary))),
                    Expanded(child: _num(_sec, 'sec')),
                  ])
                else
                  _num(_value, 'résultat', decimal: widget.scoreType == 'load'),
                // Échelle Rx/Scaled : uniquement pour les WODs à charge ; Pro/Open pour HYROX solo.
                if (_isHyrox || _hasScale) ...[
                  const SizedBox(height: HiSpace.lg),
                  Text(_isHyrox ? 'Catégorie' : 'Échelle', style: HiType.body.copyWith(color: HiColors.textSecondary)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _scaleChip(_isHyrox ? 'Pro' : 'Rx (prescrit)', true),
                    const SizedBox(width: 8),
                    _scaleChip(_isHyrox ? 'Open' : 'Scaled (adapté)', false),
                  ]),
                  if (_isHyrox || pref != null) ...[
                    const SizedBox(height: HiSpace.sm),
                    Text(_isHyrox ? 'Les classements Pro et Open sont séparés.' : 'Le classement Rx et Scaled sont séparés.',
                        style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                  ],
                ],
                const SizedBox(height: HiSpace.xl),
                HiButton(label: 'Enregistrer', loading: _loading, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scaleChip(String label, bool rx) {
    final active = _rx == rx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _rx = rx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active ? HiColors.brandGradient : null,
            color: active ? null : HiColors.bgElevated2,
            borderRadius: BorderRadius.circular(HiRadius.pill),
          ),
          child: Text(label,
              style: HiType.body.copyWith(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w600)),
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
