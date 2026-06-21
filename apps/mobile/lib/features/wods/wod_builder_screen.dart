import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/session.dart';
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
  final _name = TextEditingController();
  String _type = 'for_time';
  bool _requiresEquipment = false;
  final _timeCap = TextEditingController();
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
    _name.dispose();
    _timeCap.dispose();
    super.dispose();
  }

  String get _scoreType => _scoreTypeFor(_type);

  Map<String, dynamic> _payload({double? userResult}) {
    String amountKey(String unit) =>
        unit == 'meter' ? 'distanceMeters' : unit == 'calorie' ? 'calories' : unit == 'second' ? 'durationSec' : 'reps';
    return {
      'sex': ref.read(sessionProvider).sex ?? 'male',
      'scoreType': _scoreType,
      'wodType': _type,
      if (int.tryParse(_timeCap.text) != null) 'timeCapSec': int.parse(_timeCap.text) * 60,
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
    if (_name.text.trim().length < 2) {
      _toast('Donne un nom à ta séance.');
      return;
    }
    if (_blocks.isEmpty) {
      _toast('Ajoute au moins un mouvement.');
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = _payload()
        ..['name'] = _name.text.trim()
        ..['requiresEquipment'] = _requiresEquipment;
      payload.remove('sex');
      payload.remove('userResult');
      final id = await ref.read(apiClientProvider).createWod(payload);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => WodDetailScreen(wodId: id, wodName: _name.text.trim())),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Construire une séance'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HiSpace.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom de la séance')),
                const SizedBox(height: HiSpace.md),
                Text('Format', style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
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
                if (_scoreType == 'reps') ...[
                  const SizedBox(height: HiSpace.md),
                  Row(children: [
                    Text('Plafond (min) : ', style: TextStyle(color: HiColors.textSecondary)),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: _timeCap,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => _refreshEstimate(),
                        decoration: const InputDecoration(hintText: 'ex. 12'),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: HiSpace.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: HiColors.brandPrimary,
                  value: _requiresEquipment,
                  title: Text('Nécessite du matériel', style: TextStyle(color: HiColors.textPrimary, fontSize: 14)),
                  onChanged: (v) => setState(() => _requiresEquipment = v),
                ),
                const SizedBox(height: HiSpace.md),
                Text('Mouvements', style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: HiSpace.sm),
                ..._blocks.asMap().entries.map((e) => _blockRow(e.key, e.value)),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: HiColors.strokeStrong),
                    foregroundColor: HiColors.brandPrimary,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un mouvement'),
                  onPressed: _catalog.isEmpty ? null : _addMovement,
                ),
                const SizedBox(height: HiSpace.lg),
                _estimateCard(),
                const SizedBox(height: HiSpace.lg),
                HiButton(label: 'Publier cette séance', loading: _saving, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _blockRow(int i, _Block b) {
    final isLoaded = b.movement.category == 'weightlifting';
    return Card(
      margin: const EdgeInsets.only(bottom: HiSpace.sm),
      child: Padding(
        padding: const EdgeInsets.all(HiSpace.md),
        child: Row(
          children: [
            Expanded(child: Text(b.movement.name, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w600))),
            SizedBox(
              width: 60,
              child: TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: InputDecoration(hintText: b.movement.unit == 'meter' ? 'm' : b.movement.unit == 'calorie' ? 'cal' : 'reps'),
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
              icon: Icon(Icons.close, color: HiColors.textTertiary, size: 20),
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

  Widget _estimateCard() {
    if (_estimating) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    if (_estimate == null) {
      return Text('Ajoute des mouvements pour voir l’estimation.', textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary));
    }
    final e = _estimate!;
    final champ = e.ref('champion')?.rawResult;
    final inter = e.ref('intermediate')?.rawResult;
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
            Text('Estimation', style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: HiColors.warn.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(HiRadius.pill)),
              child: Text('≈ estimé', style: TextStyle(color: HiColors.warn, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: HiSpace.sm),
          if (champ != null) Text('🏆 Champion : ${formatWodResult(champ, _scoreType)}', style: TextStyle(color: HiColors.textSecondary)),
          if (inter != null) Text('Intermédiaire : ${formatWodResult(inter, _scoreType)}', style: TextStyle(color: HiColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: e.attributesAffected
                .map((a) => Text('◆ ${HiLabels.attribute(a)}', style: TextStyle(color: HiColors.attribute(a), fontSize: 12)))
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
              decoration: const InputDecoration(hintText: 'Rechercher un mouvement', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: HiSpace.sm),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: items.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(items[i].name, style: TextStyle(color: HiColors.textPrimary)),
                  subtitle: Text(items[i].category, style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
                  trailing: Icon(Icons.add, color: HiColors.brandPrimary),
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
