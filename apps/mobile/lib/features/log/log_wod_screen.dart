import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/wod_catalog.dart';
import '../../theme/tokens.dart';
import '../../data/review_prompt.dart';
import '../../widgets/attribute_gains.dart';
import '../../widgets/hi_button.dart';

/// Log d'une séance : choisir une séance + saisir le résultat → l'Index se recalcule.
class LogWodScreen extends ConsumerStatefulWidget {
  /// Pré-sélectionne un WOD (ex. depuis « Faire cette séance » sur la fiche).
  final String? initialWodId;
  const LogWodScreen({super.key, this.initialWodId});

  @override
  ConsumerState<LogWodScreen> createState() => _LogWodScreenState();
}

class _LogWodScreenState extends ConsumerState<LogWodScreen> {
  late WodCatalogItem _wod;

  @override
  void initState() {
    super.initState();
    _wod = wodCatalog.firstWhere(
      (w) => w.id == widget.initialWodId,
      orElse: () => wodCatalog.firstWhere((w) => w.id == 'fran'),
    );
  }
  final _value = TextEditingController(); // reps / load / distance
  final _min = TextEditingController();
  final _sec = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _value.dispose();
    _min.dispose();
    _sec.dispose();
    super.dispose();
  }

  bool get _isTime => _wod.scoreType == 'time';

  double? get _rawResult {
    if (_isTime) {
      final total = (int.tryParse(_min.text) ?? 0) * 60 + (int.tryParse(_sec.text) ?? 0);
      return total > 0 ? total.toDouble() : null;
    }
    final v = double.tryParse(_value.text.replaceAll(',', '.'));
    return (v != null && v > 0) ? v : null;
  }

  String get _unitLabel {
    switch (_wod.scoreType) {
      case 'reps':
        return 'répétitions';
      case 'load':
        return 'kg';
      case 'distance':
        return 'mètres';
      default:
        return 'temps';
    }
  }

  Future<void> _submit() async {
    final raw = _rawResult;
    if (raw == null) {
      _toast('Saisis un résultat valide.');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).logResult({
        'wodId': _wod.id,
        'scoreType': _wod.scoreType,
        'rawResult': raw,
      });
      if (!mounted) return;
      await _showResult(res.profile, res.newBadges);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (e.code == 'WOD_RESULT_OUT_OF_BOUNDS') {
        _toast('Résultat hors des bornes physiologiques attendues. Vérifie ta saisie.');
      } else {
        _toast(e.message);
      }
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showResult(Profile p, List<String> newBadges) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: HiColors.bgElevated,
        title: Text('Résultat enregistré 💪', style: TextStyle(color: HiColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nouvel HYBRID INDEX', style: TextStyle(color: HiColors.textSecondary)),
            const SizedBox(height: 8),
            Text('${p.index.value}',
                style: TextStyle(color: HiColors.brandPrimary, fontSize: 44, fontWeight: FontWeight.w800)),
            Text('${p.index.radarCoverage}/6 attributs débloqués',
                style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
            const SizedBox(height: HiSpace.md),
            AttributeGains(gains: p.gains, weakest: p.weakest),
            if (newBadges.isNotEmpty) ...[
              const SizedBox(height: HiSpace.md),
              Container(
                padding: const EdgeInsets.all(HiSpace.md),
                decoration: BoxDecoration(
                  color: HiColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(HiRadius.md),
                ),
                child: Column(
                  children: [
                    Text('🎉 Badge(s) débloqué(s) !',
                        style: TextStyle(color: HiColors.success, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    ...newBadges.map((b) => Text(b,
                        textAlign: TextAlign.center, style: TextStyle(color: HiColors.textPrimary))),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Continuer')),
        ],
      ),
    );
    // Réussite (PR ou badge) → demande d'avis natif (OS-plafonné, no-op web), jamais après une erreur.
    if (p.gains.isNotEmpty || newBadges.isNotEmpty) {
      await maybeAskForReview();
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final pref = ref.watch(sessionProvider).sex; // info seulement
    final equipped = wodCatalog.where((w) => w.requiresEquipment).toList();
    final bodyweight = wodCatalog.where((w) => !w.requiresEquipment).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Logger une séance'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HiSpace.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Choisis une séance', style: TextStyle(color: HiColors.textSecondary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<WodCatalogItem>(
                  initialValue: _wod,
                  isExpanded: true,
                  dropdownColor: HiColors.bgElevated2,
                  items: [
                    DropdownMenuItem<WodCatalogItem>(
                      enabled: false,
                      child: Text('— Sans matériel —', style: TextStyle(color: HiColors.textTertiary)),
                    ),
                    ...bodyweight.map(_item),
                    DropdownMenuItem<WodCatalogItem>(
                      enabled: false,
                      child: Text('— Avec matériel —', style: TextStyle(color: HiColors.textTertiary)),
                    ),
                    ...equipped.map(_item),
                  ],
                  onChanged: (w) {
                    if (w != null) {
                      setState(() {
                        _wod = w;
                        _value.clear();
                        _min.clear();
                        _sec.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: HiSpace.lg),
                Text('Ton résultat ($_unitLabel)', style: TextStyle(color: HiColors.textSecondary)),
                const SizedBox(height: 8),
                if (_isTime)
                  Row(
                    children: [
                      Expanded(child: _numField(_min, 'min')),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(':', style: TextStyle(color: HiColors.textSecondary, fontSize: 20)),
                      ),
                      Expanded(child: _numField(_sec, 'sec')),
                    ],
                  )
                else
                  _numField(_value, _unitLabel, allowDecimal: _wod.scoreType == 'load'),
                if (pref != null) ...[
                  const SizedBox(height: HiSpace.sm),
                  Text('Le score est normalisé selon ton sexe (classement équitable).',
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

  DropdownMenuItem<WodCatalogItem> _item(WodCatalogItem w) =>
      DropdownMenuItem<WodCatalogItem>(value: w, child: Text(w.name, style: TextStyle(color: HiColors.textPrimary)));

  Widget _numField(TextEditingController c, String hint, {bool allowDecimal = false}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: allowDecimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : [FilteringTextInputFormatter.digitsOnly],
      textAlign: _isTime ? TextAlign.center : TextAlign.start,
      decoration: InputDecoration(hintText: hint),
    );
  }
}
