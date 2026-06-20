import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';

/// Saisie d'un résultat sur un WOD (officiel ou custom) — note via le moteur si custom.
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
  final _min = TextEditingController();
  final _sec = TextEditingController();
  bool _rx = true;
  bool _loading = false;

  bool get _isTime => widget.scoreType == 'time';

  @override
  void dispose() {
    _value.dispose();
    _min.dispose();
    _sec.dispose();
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
    setState(() => _loading = true);
    try {
      final profile = await ref.read(apiClientProvider).logWodResult(widget.wodId, {'rawResult': raw, 'rxCompliant': _rx});
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      if (profile != null) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: HiColors.bgElevated,
            title: const Text('Résultat enregistré 💪', style: TextStyle(color: HiColors.textPrimary)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('HYBRID INDEX', style: TextStyle(color: HiColors.textSecondary)),
              const SizedBox(height: 8),
              Text('${profile.index.value}',
                  style: const TextStyle(color: HiColors.brandPrimary, fontSize: 44, fontWeight: FontWeight.w800)),
            ]),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Continuer'))],
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _toast(e.code == 'WOD_RESULT_OUT_OF_BOUNDS' ? 'Résultat hors des bornes plausibles.' : e.message);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                Text('Ton résultat (${_isTime ? 'temps' : widget.scoreType == 'load' ? 'kg' : widget.scoreType == 'distance' ? 'mètres' : 'reps'})',
                    style: const TextStyle(color: HiColors.textSecondary)),
                const SizedBox(height: 8),
                if (_isTime)
                  Row(children: [
                    Expanded(child: _num(_min, 'min')),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text(':', style: TextStyle(color: HiColors.textSecondary, fontSize: 20))),
                    Expanded(child: _num(_sec, 'sec')),
                  ])
                else
                  _num(_value, 'résultat', decimal: widget.scoreType == 'load'),
                const SizedBox(height: HiSpace.lg),
                const Text('Échelle', style: TextStyle(color: HiColors.textSecondary)),
                const SizedBox(height: 8),
                Row(children: [
                  _scaleChip('Rx (prescrit)', true),
                  const SizedBox(width: 8),
                  _scaleChip('Scaled (adapté)', false),
                ]),
                if (pref != null) ...[
                  const SizedBox(height: HiSpace.sm),
                  const Text('Le classement Rx et Scaled sont séparés.',
                      style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
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
              style: TextStyle(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w600)),
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
