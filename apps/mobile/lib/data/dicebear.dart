/// DiceBear — avatars premium générés, rendus via `Image.network` (zéro dépendance, build-safe).
/// Doc : https://www.dicebear.com — format `https://api.dicebear.com/{v}/{style}/png?seed=...`.
library;

const String kDiceBearVersion = '9.x';

/// Style par défaut (personnages illustrés, expressifs — bon pour une identité d'athlète).
const String kDiceBearDefaultStyle = 'adventurer';

/// Styles premium proposés à la création (libellé FR → identifiant DiceBear).
const List<({String id, String label})> kDiceBearStyles = [
  (id: 'adventurer', label: 'Aventurier'),
  (id: 'avataaars', label: 'Classique'),
  (id: 'personas', label: 'Persona'),
  (id: 'micah', label: 'Épuré'),
  (id: 'notionists', label: 'Notion'),
  (id: 'big-smile', label: 'Smile'),
];

/// URL PNG d'un avatar DiceBear. `size` en pixels (on demande ~2× la taille d'affichage pour la netteté).
String diceBearUrl({required String style, required String seed, int size = 160}) {
  final s = Uri.encodeComponent(seed);
  return 'https://api.dicebear.com/$kDiceBearVersion/$style/png?seed=$s&size=$size';
}
