import 'package:flutter/material.dart';

import '../data/glossary.dart';
import '../theme/tokens.dart';

/// Texte enrichi : détecte les termes de jargon du [kGlossary] et les rend tappables
/// (souligné pointillé + petite ℹ️). Au tap → feuille avec la définition. Seule la PREMIÈRE
/// occurrence de chaque terme est décorée (pas de bruit si le mot se répète).
class GlossaryText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const GlossaryText(this.text, {super.key, required this.style});

  // Termes triés du plus long au plus court → on préfère « pour le temps » à un éventuel sous-terme.
  static final List<String> _terms = kGlossary.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  // Termes composés uniquement de lettres/espaces → pas de métacaractère regex à échapper.
  static final RegExp _pattern = RegExp(_terms.join('|'), caseSensitive: false);
  static final RegExp _alnum = RegExp(r'[a-zA-Z0-9àâäéèêëïîôöùûüç]');

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(style: style, children: _spans(context)));
  }

  List<InlineSpan> _spans(BuildContext context) {
    final spans = <InlineSpan>[];
    final seen = <String>{};
    var last = 0;
    for (final m in _pattern.allMatches(text)) {
      final key = m.group(0)!.toLowerCase();
      if (!kGlossary.containsKey(key) || seen.contains(key)) continue;
      // Frontières de mot : le caractère adjacent ne doit pas être alphanumérique (évite « approx »→« rx »).
      final before = m.start == 0 ? '' : text[m.start - 1];
      final after = m.end >= text.length ? '' : text[m.end];
      if ((before.isNotEmpty && _alnum.hasMatch(before)) || (after.isNotEmpty && _alnum.hasMatch(after))) {
        continue;
      }
      seen.add(key);
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final term = text.substring(m.start, m.end);
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () => _showDefinition(context, term, kGlossary[key]!),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(term,
                  style: style.copyWith(
                    color: HiColors.brandPrimary,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: HiColors.brandPrimary.withValues(alpha: 0.6),
                  )),
              const SizedBox(width: 2),
              Icon(Icons.info_outline_rounded, size: (style.fontSize ?? 13) + 1, color: HiColors.brandPrimary),
            ],
          ),
        ),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  void _showDefinition(BuildContext context, String term, String definition) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HiColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HiRadius.xxl)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, HiSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: HiColors.brandPrimary),
                  const SizedBox(width: HiSpace.sm),
                  Expanded(
                    child: Text(term.toUpperCase(),
                        style: HiType.titleM.copyWith(color: HiColors.textPrimary, letterSpacing: 0.5)),
                  ),
                ],
              ),
              const SizedBox(height: HiSpace.sm),
              Text(definition, style: HiType.body.copyWith(color: HiColors.textSecondary, height: 1.45)),
            ],
          ),
        ),
      ),
    );
  }
}
