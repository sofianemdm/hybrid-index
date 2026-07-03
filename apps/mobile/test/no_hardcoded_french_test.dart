import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GARDE-FOU i18n : aucun texte français EN DUR dans le code UI (lib/features + lib/widgets +
/// lib/data/dicebear.dart). Tout texte visible passe par AppLocalizations (app_fr.arb / app_en.arb),
/// sinon l'app mélange les langues et les corrections de wording en oublient (cf. « WOD → séance »
/// resté dans les push). Détection : littéraux de chaîne contenant un caractère accentué français.
///
/// EXCEPTIONS assumées (contenu produit, pas de l'UI) :
///  - lib/data/glossary.dart : définitions du glossaire (contenu éditorial FR)
///  - lib/data/wod_catalog.dart : noms officiels des séances (« 5 km Course » = nom produit)
///  - lib/data/models.dart : valeurs de repli/parse (jamais affichées telles quelles)
void main() {
  test('aucun littéral français accentué dans le code UI', () {
    final libDir = Directory('lib');
    const allowedFiles = {
      'lib/data/glossary.dart',
      'lib/data/wod_catalog.dart',
      'lib/data/models.dart',
      // Libellés d'options de l'éditeur d'avatar (~50 : « Hâlé », « Bouclé »…) : contenu produit,
      // comme les noms de séances. À migrer seulement si l'app vise l'international complet.
      'lib/data/dicebear.dart',
      // Moteur PUR du mode guidé : ses libellés par défaut sont écrasés par GuidedLabels (l10n
      // injecté par l'écran, cf. guided_session_screen._labelsOf) — jamais affichés tels quels.
      'lib/features/guided/guided_plan.dart',
    };
    final accented = RegExp(r"""['"][^'"\n]*[éèêëàâçîïôûùüœÉÈÊÀÂÇÎÏÔÛÙ][^'"\n]*['"]""");
    final offenders = <String>[];

    for (final f in libDir.listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart')) continue;
      if (path.startsWith('lib/l10n/')) continue; // les traductions elles-mêmes
      if (allowedFiles.contains(path)) continue;
      if (!path.startsWith('lib/features/') && !path.startsWith('lib/widgets/')) {
        continue; // périmètre : le code UI (le reste = data/infra, relu au cas par cas)
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final noComment = line.split('//').first; // ignore les commentaires de fin de ligne
        if (line.trimLeft().startsWith('//')) continue;
        if (line.contains('RegExp(')) continue; // classes de caractères regex ≠ texte affiché
        final m = accented.firstMatch(noComment);
        if (m == null) continue;
        final content = m.group(0)!.substring(1, m.group(0)!.length - 1);
        // Jeu de caractères (normalisation d'accents, etc.) : long, sans espace → pas un texte UI.
        if (!content.contains(' ') && content.length > 10) continue;
        offenders.add('$path:${i + 1}: ${m.group(0)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Texte français en dur détecté — passe par AppLocalizations (arb FR/EN) :\n'
          '${offenders.join('\n')}',
    );
  });
}
