import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/widgets/net_avatar_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration GLOBALE des tests (exécutée autour de chaque fichier de test) :
/// 1. Charge les VRAIES polices (Rajdhani, Inter, MaterialIcons) — sans ça, tout le texte est
///    rendu en carrés « Ahem » et les goldens/débordements ne reflètent pas la réalité.
/// 2. Comparateur de goldens TOLÉRANT (1,5 %) : le rendu du texte diffère très légèrement entre
///    Windows (dev) et Linux (CI GitHub) — on absorbe l'anti-aliasing, pas les vrais changements.
/// 3. NetAvatarImage.testMode : les avatars réseau retombent sur Image.network (interceptée en test).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  NetAvatarImage.testMode = true;
  SharedPreferences.setMockInitialValues({});
  await _loadRealFonts();
  final base = goldenFileComparator;
  if (base is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenComparator(Uri.parse('${base.basedir}config.dart'));
  }
  await testMain();
}

/// Charge toutes les polices déclarées dans FontManifest.json (celles de pubspec + MaterialIcons).
Future<void> _loadRealFonts() async {
  final manifest = await rootBundle.loadString('FontManifest.json');
  for (final entry in (json.decode(manifest) as List)) {
    final family = (entry as Map)['family'] as String;
    // Les familles packagées « packages/x/y » gardent leur nom court côté TextStyle.
    final loader = FontLoader(family.split('/').last);
    for (final font in (entry['fonts'] as List)) {
      loader.addFont(rootBundle.load(((font as Map)['asset'] as String)));
    }
    await loader.load();
  }
}

/// Golden « quasi identique » : échoue au-delà de [_maxDiffPercent] de pixels différents.
class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile);

  static const double _maxDiffPercent = 0.015; // 1,5 % — absorbe l'anti-aliasing inter-OS

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    if (result.passed) return true;
    if (result.diffPercent <= _maxDiffPercent) return true;
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError('$error (diff ${(result.diffPercent * 100).toStringAsFixed(2)} % > seuil 1,5 %)');
  }
}
