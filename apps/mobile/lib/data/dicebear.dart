/// DiceBear — avatars premium générés, rendus via `Image.network` (zéro dépendance, build-safe).
/// Doc : https://www.dicebear.com — format `https://api.dicebear.com/{v}/{style}/png?seed=...`.

const String kDiceBearVersion = '9.x';

/// Style par défaut (personnages illustrés, expressifs — bon pour une identité d'athlète).
const String kDiceBearDefaultStyle = 'adventurer';

/// Un style premium proposé à la création.
class DiceStyle {
  final String id;
  final String label;
  const DiceStyle(this.id, this.label);
}

/// Styles proposés à la création (identifiant DiceBear → libellé FR).
const List<DiceStyle> kDiceBearStyles = [
  DiceStyle('adventurer', 'Aventurier'),
  DiceStyle('avataaars', 'Classique'),
  DiceStyle('personas', 'Persona'),
  DiceStyle('micah', 'Épuré'),
  DiceStyle('notionists', 'Notion'),
  DiceStyle('big-smile', 'Smile'),
];

/// URL PNG d'un avatar DiceBear. `size` en pixels (on demande ~2× la taille d'affichage pour la netteté).
String diceBearUrl({required String style, required String seed, int size = 160}) {
  final s = Uri.encodeComponent(seed);
  return 'https://api.dicebear.com/$kDiceBearVersion/$style/png?seed=$s&size=$size';
}
