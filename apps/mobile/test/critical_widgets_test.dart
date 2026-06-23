import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/data/models.dart';
import 'package:hybrid_index/features/home/rival_card.dart';
import 'package:hybrid_index/features/home/weekly_recap_card.dart';
import 'package:hybrid_index/l10n/app_localizations.dart';
import 'package:hybrid_index/widgets/hi_empty_state.dart';

/// Monte un widget dans un MaterialApp localisé (FR) — nécessaire pour les widgets qui appellent
/// AppLocalizations.of(context).
Future<void> pumpL(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ));
  await tester.pump();
}

void main() {
  group('RivalCard — robustesse null (régression crash accueil)', () {
    testWidgets('rival null + position ≠ 1 → état meneur, AUCUN crash', (tester) async {
      // Avant le fix : rival! sur null → « Unexpected null value ». Ne doit plus jamais arriver.
      await pumpL(tester, RivalCard(rival: null, leaguePosition: 3, onTap: () {}));
      expect(tester.takeException(), isNull);
    });

    testWidgets('rival null + position 1 → état meneur, aucun crash', (tester) async {
      await pumpL(tester, RivalCard(rival: null, leaguePosition: 1, onTap: () {}));
      expect(tester.takeException(), isNull);
    });

    testWidgets('rival présent → affiche son nom, aucun crash', (tester) async {
      const rival = Rival(displayName: 'Kevin', rank: 'platinum', ovr: 78, position: 2, gapPoints: 4);
      await pumpL(tester, RivalCard(rival: rival, leaguePosition: 3, onTap: () {}));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Kevin', findRichText: true), findsWidgets);
    });
  });

  testWidgets('WeeklyRecapCard se rend sans crash', (tester) async {
    const recap = WeeklyRecap(sessions: 3, indexNow: 76, deltaIndex: 4, streakCurrent: 5, weekValidated: true);
    await pumpL(tester, const WeeklyRecapCard(recap: recap));
    expect(tester.takeException(), isNull);
    expect(find.text('+4'), findsOneWidget); // gain d'Index affiché
  });

  group('HiEmptyState', () {
    testWidgets('affiche titre + message', (tester) async {
      await pumpL(
        tester,
        const HiEmptyState(icon: Icons.forum_rounded, title: 'Aucun message', message: 'Écris à un athlète.'),
      );
      expect(find.text('Aucun message'), findsOneWidget);
      expect(find.text('Écris à un athlète.'), findsOneWidget);
    });

    testWidgets('CTA présent quand fourni, déclenche onCta', (tester) async {
      var tapped = false;
      await pumpL(
        tester,
        HiEmptyState(
          icon: Icons.search_rounded,
          title: 'Vide',
          message: 'Rien ici.',
          ctaLabel: 'Explorer',
          onCta: () => tapped = true,
        ),
      );
      expect(find.text('Explorer'), findsOneWidget);
      await tester.tap(find.text('Explorer'));
      expect(tapped, isTrue);
    });
  });
}
