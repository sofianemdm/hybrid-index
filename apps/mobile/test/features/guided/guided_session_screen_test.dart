import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/data/models.dart';
import 'package:hybrid_index/features/guided/guided_plan.dart';
import 'package:hybrid_index/features/guided/guided_session_screen.dart';
import 'package:hybrid_index/l10n/app_localizations.dart';
import 'package:hybrid_index/widgets/hi_button.dart';

/// Monte le lecteur dans un MaterialApp localisé (FR) — requis pour AppLocalizations.of(context).
Future<void> _pump(
  WidgetTester tester, {
  required GuidedPlan plan,
  String title = 'Test WOD',
  List<GuidedCue> cues = const [],
  VoidCallback? onCompleted,
}) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: GuidedSessionScreen(
      plan: plan,
      title: title,
      cues: cues,
      onCompleted: onCompleted,
    ),
  ));
  await tester.pump();
  // Le lecteur lance un Timer.periodic(100ms) (rafraîchissement écran). On garantit que la
  // disposition (qui annule le timer) s'exécute en fin de test pour éviter « Timer still pending ».
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
  });
}

void main() {
  group('GuidedSessionScreen — rendu', () {
    testWidgets('for_time : titre + bouton Démarrer, aucun crash', (tester) async {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'for_time', capSec: 600),
        wodId: 'w1',
        scoreType: 'time',
      );
      await _pump(tester, plan: plan, title: 'Fran');

      expect(find.text('Fran'), findsOneWidget);
      // État initial : bouton Démarrer (label FR).
      expect(find.widgetWithText(HiButton, 'Démarrer'), findsOneWidget);
    });

    testWidgets('for_time : après Démarrer → Tour +1 présent, tap incrémente', (tester) async {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'for_time', capSec: 600),
        wodId: 'w1',
        scoreType: 'time',
      );
      await _pump(tester, plan: plan);

      await tester.tap(find.widgetWithText(HiButton, 'Démarrer'));
      await tester.pump();

      // Le compteur de tours manuel + le bouton Tour +1 apparaissent (manualRoundCounter).
      expect(find.text('Tour +1'), findsOneWidget);
      expect(find.textContaining('Tours :'), findsWidgets);

      await tester.tap(find.text('Tour +1'));
      await tester.pump();
      expect(find.text('Tours : 1'), findsOneWidget);
    });

    testWidgets('emom : bandeau PHASE + Passer après démarrage, pas de Tour +1', (tester) async {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'emom', rounds: 3),
        wodId: 'w2',
        scoreType: 'reps',
      );
      await _pump(tester, plan: plan);

      await tester.tap(find.widgetWithText(HiButton, 'Démarrer'));
      await tester.pump();

      // EMOM = phases auto : bouton Passer (skip), pas de Tour +1.
      expect(find.text('Passer'), findsOneWidget);
      expect(find.text('Tour +1'), findsNothing);
    });

    testWidgets('strength : bouton Série faite après démarrage', (tester) async {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'strength', rounds: 5),
        wodId: 'w3',
        scoreType: 'load',
      );
      await _pump(tester, plan: plan);

      await tester.tap(find.widgetWithText(HiButton, 'Démarrer'));
      await tester.pump();

      expect(find.text('Série faite'), findsOneWidget);
    });

    testWidgets('consignes : panneau rend les cues après démarrage', (tester) async {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'amrap', capSec: 300),
        wodId: 'w4',
        scoreType: 'reps',
      );
      await _pump(
        tester,
        plan: plan,
        cues: const [GuidedCue('10 Pull-ups'), GuidedCue('15 Push-ups', detail: '20 kg')],
      );

      await tester.tap(find.widgetWithText(HiButton, 'Démarrer'));
      await tester.pump();

      expect(find.text('10 Pull-ups'), findsOneWidget);
      expect(find.text('15 Push-ups'), findsOneWidget);
      expect(find.text('20 kg'), findsOneWidget);
    });
  });

  group('GuidedSessionScreen — complétion', () {
    testWidgets('Terminer → état TERMINÉ + onCompleted appelé une fois', (tester) async {
      var calls = 0;
      // Plan court for_time (cap 1s) ; on force la fin via « Terminer ».
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'for_time', capSec: 5),
        wodId: 'w5',
        scoreType: 'time',
      );
      await _pump(tester, plan: plan, onCompleted: () => calls++);

      await tester.tap(find.widgetWithText(HiButton, 'Démarrer'));
      await tester.pump();
      await tester.tap(find.text('Terminer'));
      await tester.pump();

      // Vue TERMINÉ : libellé de fin + crédit déclenché exactement une fois.
      expect(find.text('Séance terminée'), findsOneWidget);
      expect(calls, 1);
      // Bouton de sortie (Fermer) présent.
      expect(find.widgetWithText(HiButton, 'Fermer'), findsOneWidget);
      // Laisse retomber le flash de phase (Timer 160ms) avant le teardown.
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('onCompleted asynchrone → état Validation… puis Série créditée', (tester) async {
      final completer = Completer<void>();
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'for_time', capSec: 5),
        wodId: 'w6',
        scoreType: 'time',
      );
      await _pump(tester, plan: plan, onCompleted: () => completer.future);

      await tester.tap(find.widgetWithText(HiButton, 'Démarrer'));
      await tester.pump();
      await tester.tap(find.text('Terminer'));
      await tester.pump();

      // Pendant que le Future est en attente : état Validation…
      expect(find.text('Validation…'), findsOneWidget);

      completer.complete();
      await tester.pump(); // résout le Future
      await tester.pump(); // setState(_Credit.ok)

      expect(find.text('Série créditée 🔥'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });
  });

  group('GuidedSessionScreen — depuis CoachSession (mode simplifié)', () {
    testWidgets('fromCoachSession : pas de prep, Tour +1 manuel', (tester) async {
      final plan = GuidedPlanBuilder.fromCoachSession(
        sessionId: 'c1',
        durationMin: 20,
        description: 'Course 5 km\nGainage 3x1min',
      );
      await _pump(
        tester,
        plan: plan,
        title: 'EMOM maison',
        cues: const [GuidedCue('Course 5 km'), GuidedCue('Gainage 3x1min')],
      );

      await tester.tap(find.widgetWithText(HiButton, 'Démarrer'));
      await tester.pump();

      // Mode simplifié = compteur de tours manuel.
      expect(find.text('Tour +1'), findsOneWidget);
      expect(plan.isCoachSession, isTrue);
      // Laisse retomber le flash de phase (Timer 160ms) avant le teardown.
      await tester.pump(const Duration(milliseconds: 200));
    });
  });

  group('GuidedSessionScreen.fromWod — repli sans bloc guided', () {
    test('WodDetail sans guided → GuidedSource.fallback dérivé du type', () {
      // Vérifie le mapping pur (pas de widget) : un WOD sans `guided` retombe sur son `type`.
      const wod = WodDetail(
        id: 'x',
        name: 'Repli',
        scoreType: 'time',
        requiresEquipment: false,
        targetAttributes: [],
        male: null,
        female: null,
        myBestRaw: null,
        myBestSubScore: null,
        type: 'amrap',
      );
      // On reconstruit la même logique que le helper (méthode privée) via le builder public :
      final plan = GuidedPlanBuilder.fromWod(
        GuidedSource.fallback(type: wod.type ?? 'for_time'),
        wodId: wod.id,
        scoreType: wod.scoreType,
      );
      expect(plan.format, 'amrap');
    });
  });
}
