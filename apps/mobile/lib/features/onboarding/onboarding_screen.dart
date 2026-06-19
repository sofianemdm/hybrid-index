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

/// Wizard d'onboarding : un temps de course et/ou un max de pompes → aperçu live de l'Index,
/// puis révélation persistée. Garantit un chiffre pour 100 % des inscrits.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _course = 'none'; // none | run_1k | run_5k
  final _min = TextEditingController();
  final _sec = TextEditingController();
  bool _withPushups = true;
  double _pushups = 25;

  Profile? _preview;
  bool _previewing = false;
  bool _submitting = false;

  @override
  void dispose() {
    _min.dispose();
    _sec.dispose();
    super.dispose();
  }

  int? get _courseSeconds {
    if (_course == 'none') return null;
    final m = int.tryParse(_min.text) ?? 0;
    final s = int.tryParse(_sec.text) ?? 0;
    final total = m * 60 + s;
    return total > 0 ? total : null;
  }

  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{};
    final cs = _courseSeconds;
    if (cs != null) payload['course'] = {'wodId': _course, 'timeSeconds': cs};
    if (_withPushups) payload['estimatedPushups'] = _pushups.round();
    return payload;
  }

  bool get _hasInput => _courseSeconds != null || _withPushups;

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
      // l'aperçu est best-effort
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _reveal() async {
    if (!_hasInput) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute un temps de course ou tes pompes.')),
      );
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

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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

                  // Course
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(HiSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Temps de course (optionnel)',
                              style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              _chip('Aucun', 'none'),
                              _chip('1 km', 'run_1k'),
                              _chip('5 km', 'run_5k'),
                            ],
                          ),
                          if (_course != 'none') ...[
                            const SizedBox(height: HiSpace.md),
                            Row(
                              children: [
                                Expanded(child: _timeField(_min, 'min')),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(':', style: TextStyle(color: HiColors.textSecondary, fontSize: 20)),
                                ),
                                Expanded(child: _timeField(_sec, 'sec')),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: HiSpace.md),

                  // Pompes
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(HiSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Max pompes strictes',
                                    style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w600)),
                              ),
                              Switch(
                                value: _withPushups,
                                activeThumbColor: HiColors.brandPrimary,
                                onChanged: (v) {
                                  setState(() => _withPushups = v);
                                  _refreshPreview();
                                },
                              ),
                            ],
                          ),
                          if (_withPushups)
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _pushups,
                                    min: 0,
                                    max: 100,
                                    divisions: 100,
                                    activeColor: HiColors.brandPrimary,
                                    label: '${_pushups.round()}',
                                    onChanged: (v) => setState(() => _pushups = v),
                                    onChangeEnd: (_) => _refreshPreview(),
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  child: Text('${_pushups.round()}',
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: HiSpace.lg),

                  // Aperçu live
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

  Widget _chip(String label, String value) {
    final active = _course == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      showCheckmark: false,
      selectedColor: HiColors.brandPrimary,
      backgroundColor: HiColors.bgElevated2,
      labelStyle: TextStyle(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w600),
      side: const BorderSide(color: HiColors.strokeSubtle),
      onSelected: (_) {
        setState(() => _course = value);
        _refreshPreview();
      },
    );
  }

  Widget _timeField(TextEditingController c, String hint) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      decoration: InputDecoration(hintText: hint),
      onChanged: (_) => _refreshPreview(),
    );
  }
}
