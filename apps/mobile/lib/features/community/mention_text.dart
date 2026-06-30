import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../profile/public_profile_screen.dart';

/// Rend un texte (post ou commentaire) en rendant CLIQUABLES les `@pseudo` que le back a résolus
/// (liste [mentions] : offset/length sur [text], userId/pseudo canoniques). Un tap sur une mention
/// ouvre le profil public de l'utilisateur. Les `@` non résolus restent du texte ordinaire.
///
/// Robuste : on borne chaque offset/length au texte effectif et on ignore les chevauchements
/// (jamais d'exception de RangeError, même si le back et le client divergent sur le découpage).
class MentionText extends StatefulWidget {
  const MentionText(
    this.text, {
    super.key,
    this.mentions = const <Mention>[],
    required this.baseStyle,
    this.mentionColor,
  });

  final String text;
  final List<Mention> mentions;
  final TextStyle baseStyle;
  final Color? mentionColor;

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  // Les TapGestureRecognizer doivent être libérés pour ne pas fuiter.
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _open(BuildContext context, String userId) {
    if (userId.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId)));
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = widget.text;
    final mentionColor = widget.mentionColor ?? HiColors.brandPrimary;

    // Aucune mention → texte simple (chemin rapide, pas de RichText inutile).
    if (widget.mentions.isEmpty) {
      return Text(text, style: widget.baseStyle);
    }

    // On ne garde que les mentions dont l'intervalle [offset, offset+length) tient dans le texte,
    // triées par offset, sans chevauchement (on saute toute mention qui démarre avant la fin de
    // la précédente — protège d'éventuels offsets incohérents).
    final valid = widget.mentions
        .where((m) => m.offset >= 0 && m.length > 0 && m.offset + m.length <= text.length)
        .toList()
      ..sort((a, b) => a.offset.compareTo(b.offset));

    final spans = <InlineSpan>[];
    var cursor = 0;
    final t = AppLocalizations.of(context);
    for (final m in valid) {
      if (m.offset < cursor) continue; // chevauchement → on ignore
      if (m.offset > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.offset)));
      }
      final token = text.substring(m.offset, m.offset + m.length);
      final recognizer = TapGestureRecognizer()..onTap = () => _open(context, m.userId);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: token,
        style: TextStyle(color: mentionColor, fontWeight: FontWeight.w700),
        recognizer: recognizer,
        semanticsLabel: t.a11yMention(m.pseudo),
      ));
      cursor = m.offset + m.length;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: widget.baseStyle, children: spans));
  }
}
