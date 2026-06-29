import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import '../avatar/dice_avatar_screen.dart';
import '../reveal/reveal_screen.dart';

/// Wizard d'onboarding : l'utilisateur saisit LUI-MÊME sa distance de course + son temps
/// (n'importe quelle distance, normalisée Riegel), et/ou un max de pompes / squats en une série.
/// Aperçu live de l'Index, puis révélation persistée.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0; // 0 = avatar, 1 = efforts
  AvatarConfig _avatar = const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1);

  bool _withCourse = false; // OFF par défaut : les pompes (ON) suffisent au 1er reveal (UX-01)
  final _km = TextEditingController(text: '3');
  final _min = TextEditingController();
  final _sec = TextEditingController();

  bool _withPushups = true;
  double _pushups = 25;

  bool _withPullups = false;
  double _pullups = 5;

  bool _withSquat = false;
  final _squat = TextEditingController();

  Profile? _preview;
  bool _previewing = false;
  bool _submitting = false;

  @override
  void dispose() {
    _km.dispose();
    _min.dispose();
    _sec.dispose();
    _squat.dispose();
    super.dispose();
  }

  /// Distance en mètres si la saisie est valide (0,4 à 42,2 km).
  int? get _distanceMeters {
    if (!_withCourse) return null;
    final km = double.tryParse(_km.text.replaceAll(',', '.'));
    if (km == null) return null;
    final m = (km * 1000).round();
    return (m >= 400 && m <= 42200) ? m : null;
  }

  int? get _courseSeconds {
    if (!_withCourse) return null;
    final total = (int.tryParse(_min.text) ?? 0) * 60 + (int.tryParse(_sec.text) ?? 0);
    return total > 0 ? total : null;
  }

  bool get _courseValid => _distanceMeters != null && _courseSeconds != null;

  // Bornes par sexe alignées sur le score-service (wods.data.ts : hardMin/hardMax). On clampe la
  // saisie front à ces bornes pour qu'AUCUN effort ne soit refusé (422) au reveal — un seul effort
  // hors bornes ferait échouer tout le calcul du profil. Source de vérité = score-service.
  bool get _isFemale => (ref.read(sessionProvider).sex ?? 'male') == 'female';
  double get _pushupsMax => 70; // slider pompes 1–70 (≤ hardMax 80 F / 110 H)
  double get _pullupsMax => _isFemale ? 35 : 50; // slider tractions 1–50 H (35 F = hardMax sexe)
  int get _squatMin => _isFemale ? 15 : 20; // hardMin 15 F / 20 H
  int get _squatMax => _isFemale ? 220 : 320; // hardMax 220 F / 320 H

  /// Charge du squat 1RM en kg si la saisie est valide (dans les bornes plausibles du sexe).
  int? get _squatKg {
    if (!_withSquat) return null;
    final kg = int.tryParse(_squat.text);
    return (kg != null && kg >= _squatMin && kg <= _squatMax) ? kg : null;
  }

  bool get _hasInput => _courseValid || _withPushups || _withPullups || _squatKg != null;

  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{};
    if (_courseValid) {
      payload['course'] = {'distanceMeters': _distanceMeters, 'timeSeconds': _courseSeconds};
    }
    if (_withPushups) payload['estimatedPushups'] = _pushups.round();
    if (_withPullups) payload['estimatedStrictPullups'] = _pullups.round();
    if (_squatKg != null) payload['estimatedSquat1rmKg'] = _squatKg;
    return payload;
  }

  Future<void> _refreshPreview() async {
    if (!_hasInput) {
      setState(() => _preview = null);
      return;
    }
    final session = ref.read(sessionProvider);
    setState(() => _previewing = true);
    try {
      final payload = _buildPayload()
        ..['sex'] = session.sex ?? 'male'
        ..['goal'] = session.goal ?? 'hyrox';
      final p = await ref.read(apiClientProvider).onboardingEstimate(payload);
      if (mounted) setState(() => _preview = p);
    } catch (_) {
      // aperçu best-effort (ex. distance/temps incohérents → on n'affiche rien)
      if (mounted) setState(() => _preview = null);
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _reveal() async {
    if (!_hasInput) {
      _toast(AppLocalizations.of(context).onbNeedEffort);
      return;
    }
    // On ne bloque QUE si la course est le SEUL effort tenté mais incomplète. Si un autre effort
    // valide existe (pompes/tractions/squat), une course incomplète est simplement ignorée du
    // payload (cf. _buildPayload) — le reveal n'est jamais bloqué inutilement (UX-01).
    final hasOtherEffort = _withPushups || _withPullups || _squatKg != null;
    if (_withCourse && !_courseValid && !hasOtherEffort) {
      _toast(AppLocalizations.of(context).onbRunNeedsBoth);
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.updateAvatar(_avatar); // sauvegarde l'avatar créé à l'onboarding
      ref.invalidate(avatarProvider);
      final profile = await api.onboardingComplete(_buildPayload());
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevealScreen(profile: profile)));
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            child: Text(AppLocalizations.of(context).commonLogout, style: TextStyle(color: HiColors.textTertiary)),
          ),
        ],
      ),
      body: SafeArea(
        child: _step == 0 ? _avatarLayout() : _effortsLayout(),
      ),
    );
  }

  // Étape 0 — création de l'avatar (éditeur DiceBear plein écran : il a besoin de hauteur bornée).
  Widget _avatarLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progression d'étape annoncée (header + liveRegion) avant le titre de l'étape.
                  Semantics(
                    header: true,
                    liveRegion: true,
                    label: AppLocalizations.of(context).a11yOnbStep(1, 2),
                    child: const SizedBox.shrink(),
                  ),
                  Text(AppLocalizations.of(context).onbAvatarTitle,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: HiColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text(AppLocalizations.of(context).onbAvatarSubtitle,
                      style: TextStyle(color: HiColors.textSecondary)),
                ],
              ),
            ),
            Expanded(
              child: DiceAvatarEditor(
                sex: ref.read(sessionProvider).sex ?? 'male',
                initial: _avatar,
                onChanged: (c) => _avatar = c,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, HiSpace.lg),
              child: HiButton(
                  label: AppLocalizations.of(context).commonContinue,
                  // En arrivant à l'étape efforts, on calcule tout de suite l'aperçu d'Index (pompes ON
                  // par défaut → un chiffre s'affiche immédiatement, le « waouh » anticipé qui motive).
                  onPressed: () {
                    setState(() => _step = 1);
                    _refreshPreview();
                  }),
            ),
          ],
        ),
      ),
    );
  }

  // Étape 1 — efforts (scroll classique).
  Widget _effortsLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(HiSpace.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _effortsStep(),
          ),
        ),
      ),
    );
  }

  List<Widget> _effortsStep() => [
        // Progression d'étape annoncée (header + liveRegion) à l'arrivée sur les efforts.
        Semantics(
          header: true,
          liveRegion: true,
          label: AppLocalizations.of(context).a11yOnbStep(2, 2),
          child: const SizedBox.shrink(),
        ),
        Text(AppLocalizations.of(context).onbRevealTitle,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: HiColors.textPrimary)),
        const SizedBox(height: 6),
        Text(AppLocalizations.of(context).onbRevealSubtitle,
            style: TextStyle(color: HiColors.textSecondary)),
        const SizedBox(height: HiSpace.lg),
        _courseCard(),
        const SizedBox(height: HiSpace.md),
        _repsCard(
          title: AppLocalizations.of(context).onbMaxPushups,
          enabled: _withPushups,
          value: _pushups.clamp(1, _pushupsMax),
          max: _pushupsMax,
          onToggle: (v) {
            setState(() => _withPushups = v);
            _refreshPreview();
          },
          onChanged: (v) => setState(() => _pushups = v),
        ),
        const SizedBox(height: HiSpace.md),
        _repsCard(
          title: AppLocalizations.of(context).onbMaxPullups,
          enabled: _withPullups,
          value: _pullups.clamp(1, _pullupsMax),
          max: _pullupsMax,
          onToggle: (v) {
            setState(() => _withPullups = v);
            _refreshPreview();
          },
          onChanged: (v) => setState(() => _pullups = v),
        ),
        const SizedBox(height: HiSpace.md),
        _squatCard(),
        const SizedBox(height: HiSpace.lg),
        _previewCard(),
        const SizedBox(height: HiSpace.lg),
        HiButton(
          label: AppLocalizations.of(context).onbRevealCta,
          loading: _submitting,
          onPressed: _hasInput ? _reveal : null,
        ),
        const SizedBox(height: HiSpace.lg),
      ];

  Widget _courseCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HiSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Le titre et l'interrupteur lus comme un seul contrôle activable.
            MergeSemantics(
              child: Row(
              children: [
                Expanded(
                  child: Text(AppLocalizations.of(context).onbRunTitle,
                      style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: _withCourse,
                  activeThumbColor: HiColors.brandPrimary,
                  onChanged: (v) {
                    setState(() => _withCourse = v);
                    _refreshPreview();
                  },
                ),
              ],
            ),
            ),
            if (_withCourse) ...[
              const SizedBox(height: HiSpace.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: _field(_km, 'distance', suffix: 'km', decimal: true),
                  ),
                  const SizedBox(width: HiSpace.md),
                  Expanded(flex: 2, child: _field(_min, 'min')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(':', style: TextStyle(color: HiColors.textSecondary, fontSize: 20)),
                  ),
                  Expanded(flex: 2, child: _field(_sec, 'sec')),
                ],
              ),
              const SizedBox(height: 6),
              Text(AppLocalizations.of(context).onbRunHint,
                  style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _squatCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HiSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Row(
              children: [
                Expanded(
                  child: Text(AppLocalizations.of(context).onbSquat1rm,
                      style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: _withSquat,
                  activeThumbColor: HiColors.brandPrimary,
                  onChanged: (v) {
                    setState(() => _withSquat = v);
                    _refreshPreview();
                  },
                ),
              ],
            ),
            ),
            if (_withSquat) ...[
              const SizedBox(height: HiSpace.sm),
              SizedBox(width: 150, child: _field(_squat, '$_squatMin–$_squatMax', suffix: 'kg')),
              const SizedBox(height: 6),
              Text('${AppLocalizations.of(context).onbSquat1rmHint} ($_squatMin–$_squatMax kg)',
                  style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _repsCard({
    required String title,
    required bool enabled,
    required double value,
    required double max,
    required ValueChanged<bool> onToggle,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HiSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Row(
              children: [
                Expanded(
                  child: Text(title, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: enabled,
                  activeThumbColor: HiColors.brandPrimary,
                  onChanged: onToggle,
                ),
              ],
            ),
            ),
            if (enabled)
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: value.clamp(1, max),
                      min: 1,
                      max: max,
                      divisions: (max - 1).round(),
                      activeColor: HiColors.brandPrimary,
                      label: '${value.round()}',
                      onChanged: onChanged,
                      onChangeEnd: (_) => _refreshPreview(),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('${value.round()}',
                        textAlign: TextAlign.end,
                        style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewCard() {
    if (_previewing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HiSpace.md),
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: HiColors.brandPrimary)),
        ),
      );
    }
    if (_preview == null) {
      return Text(AppLocalizations.of(context).onbEstimatedIndexHere,
          textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary));
    }
    // a11y : l'aperçu d'Index se met à jour à chaque réglage → liveRegion qui lit « Index estimé X »
    // (le visuel est résumé par le label, son détail est exclu pour éviter la double lecture).
    return Semantics(
      liveRegion: true,
      label: '${AppLocalizations.of(context).onbEstimatedIndexLabel} ${_preview!.index.value}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: HiSpace.md),
          decoration: BoxDecoration(
            color: HiColors.bgElevated,
            borderRadius: BorderRadius.circular(HiRadius.md),
            border: Border.all(color: HiColors.strokeSubtle),
          ),
          child: Column(
            children: [
              Text(AppLocalizations.of(context).onbEstimatedIndexLabel,
                  style: TextStyle(color: HiColors.textSecondary, fontSize: 11, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text('${_preview!.index.value}',
                  style: TextStyle(color: HiColors.brandPrimary, fontSize: 40, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {String? suffix, bool decimal = false}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: decimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      decoration: InputDecoration(hintText: hint, suffixText: suffix),
      onChanged: (_) => _refreshPreview(),
    );
  }
}
