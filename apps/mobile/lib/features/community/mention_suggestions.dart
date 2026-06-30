import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_avatar.dart';

/// Détecte un token `@…` EN COURS DE SAISIE juste avant le curseur. Renvoie la requête (sans le `@`)
/// et la position du `@`, ou null si le curseur n'est pas dans une mention en cours.
///
/// Règles : le `@` doit être en début de texte ou précédé d'un séparateur (espace/saut de ligne),
/// et le token ne doit contenir que des caractères de pseudo (lettres/chiffres/_.-). Dès qu'on tape
/// une espace après, la mention est « validée » et l'autocomplete se ferme.
({String query, int atIndex})? activeMentionQuery(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;
  // On remonte depuis le curseur jusqu'au `@` ou à un séparateur.
  var i = caret - 1;
  while (i >= 0) {
    final ch = text[i];
    if (ch == '@') {
      // Le `@` doit être en tête ou précédé d'un séparateur (évite les e-mails « a@b »).
      if (i == 0 || _isSep(text[i - 1])) {
        return (query: text.substring(i + 1, caret), atIndex: i);
      }
      return null;
    }
    if (_isSep(ch) || !_isPseudoChar(ch)) return null;
    i--;
  }
  return null;
}

bool _isSep(String ch) => ch == ' ' || ch == '\n' || ch == '\t';
bool _isPseudoChar(String ch) {
  final c = ch.codeUnitAt(0);
  final isLetter = (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c > 127; // lettres + accents
  final isDigit = c >= 48 && c <= 57;
  return isLetter || isDigit || ch == '_' || ch == '.' || ch == '-';
}

/// Normalise pour comparer un pseudo (minuscules + suppression naïve des accents courants).
String _norm(String s) {
  const from = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final buf = StringBuffer();
  for (final ch in s.toLowerCase().runes) {
    final c = String.fromCharCode(ch);
    final idx = from.indexOf(c);
    buf.write(idx >= 0 ? to[idx] : c);
  }
  return buf.toString();
}

/// Bande de suggestions de mentions (au-dessus du champ). N'apparaît que si [candidates] non vide.
/// Un tap remplace le token `@query` (à partir de [atIndex]) par `@pseudo ` et repositionne le curseur.
class MentionSuggestionStrip extends StatelessWidget {
  const MentionSuggestionStrip({
    super.key,
    required this.controller,
    required this.candidates,
  });

  /// Champ piloté (on lit/écrit son texte et sa sélection).
  final TextEditingController controller;

  /// Pseudos candidats déjà filtrés et bornés (max ~5) par l'appelant.
  final List<AthleteSummary> candidates;

  void _pick(AthleteSummary a) {
    final text = controller.text;
    final sel = controller.selection;
    final caret = sel.isValid ? sel.baseOffset : text.length;
    final active = activeMentionQuery(text, caret);
    if (active == null) return;
    final before = text.substring(0, active.atIndex);
    final after = text.substring(caret);
    final inserted = '@${a.displayName} ';
    final next = '$before$inserted$after';
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: (before + inserted).length),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: const BoxConstraints(maxHeight: 168),
      decoration: BoxDecoration(
        color: HiColors.bgElevated2,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          for (final a in candidates)
            ListTile(
              dense: true,
              leading: HiAvatar(
                config: const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1),
                rank: a.rank,
                size: 28,
              ),
              title: Text('@${a.displayName}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w600)),
              onTap: () => _pick(a),
            ),
        ],
      ),
    );
  }
}

/// Filtre [pool] selon le token de mention actif dans [controller] (ou renvoie [] si pas de `@…`).
/// Borne à [max] résultats. Pensé pour être appelé dans `build` après un `setState` sur `onChanged`.
List<AthleteSummary> mentionCandidates(
  TextEditingController controller,
  List<AthleteSummary> pool, {
  int max = 5,
}) {
  final sel = controller.selection;
  final caret = sel.isValid ? sel.baseOffset : controller.text.length;
  final active = activeMentionQuery(controller.text, caret);
  if (active == null) return const [];
  final q = _norm(active.query);
  final matches = pool.where((a) => _norm(a.displayName).contains(q)).take(max).toList();
  return matches;
}
