import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_card.dart';

/// Carte « Ta semaine » — récap non compétitif, toujours valorisant. Affichée seulement s'il y a
/// quelque chose à montrer (au moins une séance ou un gain d'Index cette semaine).
class WeeklyRecapCard extends StatelessWidget {
  final WeeklyRecap recap;
  const WeeklyRecapCard({super.key, required this.recap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return MergeSemantics(
      child: Semantics(
        label: t.recapA11y(recap.sessions, recap.deltaIndex, recap.streakCurrent),
        container: true,
        child: ExcludeSemantics(child: _card(t)),
      ),
    );
  }

  Widget _card(AppLocalizations t) {
    return HiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: HiColors.brandPrimary, size: 16),
              const SizedBox(width: HiSpace.sm),
              Text(t.recapWeekLabel, style: HiType.overline.copyWith(color: HiColors.textSecondary)),
              const Spacer(),
              if (recap.weekValidated)
                Text(t.recapValidated, style: HiType.caption.copyWith(color: HiColors.success)),
            ],
          ),
          const SizedBox(height: HiSpace.md),
          Row(
            children: [
              _stat('${recap.sessions}', recap.sessions > 1 ? t.recapSessionsPlural : t.recapSessionsSingular, HiColors.brandPrimary),
              _divider(),
              _stat(recap.deltaIndex > 0 ? '+${recap.deltaIndex}' : '—', t.recapIndexPoints, HiColors.success),
              _divider(),
              _stat('${recap.streakCurrent}', recap.streakCurrent > 1 ? t.recapWeeksPlural : t.recapWeeksSingular,
                  HiColors.streakFlame),
            ],
          ),
          const SizedBox(height: HiSpace.sm),
          Text(_message(t), style: HiType.caption.copyWith(color: HiColors.textSecondary)),
        ],
      ),
    );
  }

  String _message(AppLocalizations t) {
    if (recap.deltaIndex > 0 && recap.sessions > 0) {
      return t.recapMessageGain(recap.deltaIndex);
    }
    if (recap.sessions > 0) return t.recapMessageKeepGoing;
    return t.recapMessageStart;
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: HiType.numericL.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: HiColors.strokeSubtle);
}
