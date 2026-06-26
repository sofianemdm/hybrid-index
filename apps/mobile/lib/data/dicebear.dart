// DiceBear — avatars premium générés, rendus via `Image.network` (zéro dépendance, build-safe).
// Doc : https://www.dicebear.com — format `https://api.dicebear.com/{v}/{style}/png?...`.

const String kDiceBearVersion = '9.x';
const String kDiceBearDefaultStyle = 'adventurer';

/// Style fixe de l'éditeur complet : le seul qui gère peau + coupe + barbe + lunettes + yeux + visage.
const String kAvataaarsStyle = 'avataaars';

/// URL PNG basique (style + seed) — sert au rendu des anciens avatars (sans options).
String diceBearUrl({required String style, required String seed, int size = 160}) {
  final s = Uri.encodeComponent(seed);
  return 'https://api.dicebear.com/$kDiceBearVersion/$style/png?seed=$s&size=$size';
}

// ------------------------- Éditeur complet (avataaars) -------------------------

/// Une valeur réglable (valeur DiceBear + libellé FR). `value == 'none'` = aucune (barbe/lunettes).
class DiceOption {
  final String value;
  final String label;
  const DiceOption(this.value, this.label);
}

/// Une catégorie réglable. `isColor` → pastilles couleur ; sinon → vignettes d'avatar.
class DiceCategory {
  final String key; // param DiceBear
  final String label;
  final bool isColor;
  final List<DiceOption> options;
  const DiceCategory({required this.key, required this.label, required this.isColor, required this.options});
}

// --- Catégories communes (valeurs toutes vérifiées contre l'API DiceBear avataaars v9) ---
const DiceCategory _skin = DiceCategory(key: 'skinColor', label: 'Peau', isColor: true, options: [
  DiceOption('ffdbb4', 'Clair'),
  DiceOption('edb98a', 'Clair doré'),
  DiceOption('fd9841', 'Hâlé'),
  DiceOption('d08b5b', 'Mat'),
  DiceOption('ae5d29', 'Foncé'),
  DiceOption('614335', 'Très foncé'),
]);

const DiceCategory _hairColor = DiceCategory(key: 'hairColor', label: 'Couleur', isColor: true, options: [
  DiceOption('2c1b18', 'Noir'),
  DiceOption('4a312c', 'Brun'),
  DiceOption('a55728', 'Châtain'),
  DiceOption('b58143', 'Blond'),
  DiceOption('c93305', 'Roux'),
  DiceOption('e8e1e1', 'Gris'),
]);

const DiceCategory _beard = DiceCategory(key: 'facialHair', label: 'Barbe', isColor: false, options: [
  DiceOption('none', 'Aucune'),
  DiceOption('beardLight', 'Légère'),
  DiceOption('beardMedium', 'Moyenne'),
  DiceOption('beardMajestic', 'Fournie'),
  DiceOption('moustacheFancy', 'Moustache'),
]);

const DiceCategory _glasses = DiceCategory(key: 'accessories', label: 'Lunettes', isColor: false, options: [
  DiceOption('none', 'Aucune'),
  DiceOption('round', 'Rondes'),
  DiceOption('prescription01', 'Fines'),
  DiceOption('prescription02', 'Carrées'),
  DiceOption('sunglasses', 'Soleil'),
  DiceOption('wayfarers', 'Wayfarer'),
]);

const DiceCategory _eyes = DiceCategory(key: 'eyes', label: 'Yeux', isColor: false, options: [
  DiceOption('default', 'Normal'),
  DiceOption('happy', 'Joyeux'),
  DiceOption('wink', 'Clin d\'œil'),
  DiceOption('squint', 'Plissés'),
  DiceOption('surprised', 'Surpris'),
  DiceOption('side', 'De côté'),
]);

const DiceCategory _mouth = DiceCategory(key: 'mouth', label: 'Bouche', isColor: false, options: [
  DiceOption('smile', 'Sourire'),
  DiceOption('default', 'Neutre'),
  DiceOption('serious', 'Sérieux'),
  DiceOption('twinkle', 'Malicieux'),
  DiceOption('tongue', 'Langue'),
  DiceOption('grimace', 'Grimace'),
]);

const DiceCategory _eyebrows = DiceCategory(key: 'eyebrows', label: 'Sourcils', isColor: false, options: [
  DiceOption('default', 'Naturel'),
  DiceOption('defaultNatural', 'Détendu'),
  DiceOption('flatNatural', 'Plat'),
  DiceOption('raisedExcited', 'Relevé'),
  DiceOption('upDown', 'Asymétrique'),
  DiceOption('angry', 'Froncé'),
]);

// --- Coupes de cheveux différenciées par sexe ---
const DiceCategory _hairMale = DiceCategory(key: 'top', label: 'Cheveux', isColor: false, options: [
  DiceOption('shortFlat', 'Court'),
  DiceOption('shortWaved', 'Court ondulé'),
  DiceOption('shortCurly', 'Court bouclé'),
  DiceOption('shortRound', 'Court rond'),
  DiceOption('theCaesar', 'César'),
  DiceOption('theCaesarAndSidePart', 'César raie'),
  DiceOption('sides', 'Dégarni'),
  DiceOption('dreads01', 'Dreads'),
  DiceOption('fro', 'Afro'),
]);

const DiceCategory _hairFemale = DiceCategory(key: 'top', label: 'Cheveux', isColor: false, options: [
  DiceOption('longButNotTooLong', 'Long'),
  DiceOption('bob', 'Carré'),
  DiceOption('bun', 'Chignon'),
  DiceOption('curly', 'Bouclé'),
  DiceOption('straight01', 'Lisse'),
  DiceOption('straightAndStrand', 'Lisse mèche'),
  DiceOption('bigHair', 'Volume'),
  DiceOption('miaWallace', 'Frange'),
  DiceOption('shavedSides', 'Rasé côtés'),
]);

/// Catégories de l'éditeur selon le sexe : barbe = hommes uniquement ; coupes différenciées.
List<DiceCategory> avataaarsCategoriesFor(String sex) {
  final female = sex == 'female';
  return [
    _skin,
    female ? _hairFemale : _hairMale,
    _hairColor,
    if (!female) _beard, // barbe = hommes uniquement
    _glasses,
    _eyes,
    _mouth,
    _eyebrows,
  ];
}

/// Avatar de départ selon le sexe (femme : cheveux longs, jamais de barbe).
Map<String, String> avataaarsDefaultsFor(String sex) {
  final female = sex == 'female';
  return {
    'skinColor': 'edb98a',
    'top': female ? 'longButNotTooLong' : 'shortFlat',
    'hairColor': '2c1b18',
    'facialHair': 'none', // femme : forcé à aucune (catégorie masquée) ; homme : modifiable
    'accessories': 'none',
    'eyes': 'default',
    'mouth': 'smile',
    'eyebrows': 'default',
  };
}

/// URL avataaars construite depuis les options choisies. `seed` fixe de façon stable les parties non
/// réglées (vêtements). Gère le « aucune » (barbe/lunettes) via la probabilité.
String avataaarsUrl({required Map<String, String> options, String seed = 'athlete', int size = 160}) {
  final params = <String>['seed=${Uri.encodeComponent(seed)}', 'size=$size'];
  options.forEach((k, v) {
    if (k == 'facialHair') {
      if (v == 'none') {
        params.add('facialHairProbability=0');
      } else {
        params.add('facialHair=$v');
        params.add('facialHairProbability=100');
      }
    } else if (k == 'accessories') {
      if (v == 'none') {
        params.add('accessoriesProbability=0');
      } else {
        params.add('accessories=$v');
        params.add('accessoriesProbability=100');
      }
    } else {
      params.add('$k=$v');
    }
  });
  return 'https://api.dicebear.com/$kDiceBearVersion/$kAvataaarsStyle/png?${params.join('&')}';
}
