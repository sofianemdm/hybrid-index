import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
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
  bool _withCourse = true;
  final _km = TextEditingController(text: '3');
  final _min = TextEditingController();
  final _sec = TextEditingController();

  bool _withPushups = true;
  double _pushups = 25;

  bool _withAirSquats = false;
  double _airSquats = 40;

  Profile? _preview;
  bool _previewing = false;
  bool _submitting = false;

  @override
  void dispose() {
    _km.dispose();
    _min.dispose();
    _sec.dispose();
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
  bool get _hasInput => _courseValid || _withPushups || _withAirSquats;

  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{};
    if (_courseValid) {
      payload['course'] = {'distanceMeters': _distanceMeters, 'timeSeconds': _courseSeconds};
    }
    if (_withPushups) payload['estimatedPushups'] = _pushups.round();
    if (_withAirSquats) payload['estimatedAirSquats'] = _airSquats.round();
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
      _toast('Ajoute une course, des pompes ou des squats.');
      return;
    }
    if (_withCourse && !_courseValid) {
      _toast('Distance (0,4–42 km) et temps requis pour la course.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final profile = await ref.read(apiClientProvider).onboardingComplete(_buildPayload());
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
            child: const Text('Déconnexion', style: TextStyle(color: HiColors.textTertiary)),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HiSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Révèle ton Index',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: HiColors.textPrimary)),
                  const SizedBox(height: 6),
                  const Text('Un effort suffit. Ajoutes-en plus pour un Index plus précis.',
                      style: TextStyle(color: HiColors.textSecondary)),
                  const SizedBox(height: HiSpace.lg),

                  _courseCard(),
                  const SizedBox(height: HiSpace.md),
                  _repsCard(
                    title: 'Max pompes strictes (une série)',
                    enabled: _withPushups,
                    value: _pushups,
                    max: 100,
                    onToggle: (v) {
                      setState(() => _withPushups = v);
                      _refreshPreview();
                    },
                    onChanged: (v) => setState(() => _pushups = v),
                  ),
                  const SizedBox(height: HiSpace.md),
                  _repsCard(
                    title: 'Max squats à vide (une série)',
                    enabled: _withAirSquats,
                    value: _airSquats,
                    max: 200,
                    onToggle: (v) {
                      setState(() => _withAirSquats = v);
                      _refreshPreview();
                    },
                    onChanged: (v) => setState(() => _airSquats = v),
                  ),
                  const SizedBox(height: HiSpace.lg),

                  _previewCard(),
                  const SizedBox(height: HiSpace.lg),

                  HiButton(
                    label: 'Révéler mon HYBRID INDEX',
                    loading: _submitting,
                    onPressed: _hasInput ? _reveal : null,
                  ),
                  const SizedBox(height: HiSpace.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _courseCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HiSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Course (saisis ta distance)',
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
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(':', style: TextStyle(color: HiColors.textSecondary, fontSize: 20)),
                  ),
                  Expanded(flex: 2, child: _field(_sec, 'sec')),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Ex. 3 km en 15:00. On calcule ton allure et on l’ajuste à toutes distances.',
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
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: enabled,
                  activeThumbColor: HiColors.brandPrimary,
                  onChanged: onToggle,
                ),
              ],
            ),
            if (enabled)
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: value,
                      min: 0,
                      max: max,
                      divisions: max.round(),
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
                        style: const TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(HiSpace.md),
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (_preview == null) {
      return const Text('Ton Index estimé s’affichera ici.',
          textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary));
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Column(
        children: [
          const Text('INDEX ESTIMÉ', style: TextStyle(color: HiColors.textSecondary, fontSize: 11, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text('${_preview!.index.value}',
              style: const TextStyle(color: HiColors.brandPrimary, fontSize: 40, fontWeight: FontWeight.w800)),
        ],
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
