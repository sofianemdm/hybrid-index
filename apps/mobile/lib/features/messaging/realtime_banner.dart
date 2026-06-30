import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/realtime_service.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'chat_screen.dart';

/// Observateur temps réel MONTÉ AU NIVEAU APP (dans `HomeShell`) qui affiche un BANDEAU in-app
/// non bloquant « Nouveau message de X » lorsqu'un DM arrive ALORS QUE l'utilisateur n'est PAS dans
/// la conversation concernée (autre onglet, autre chat, liste…). Quand il EST dans le chat visé, le
/// message apparaît déjà directement dans le fil (cf. `ChatScreen._appendRealtime`) → pas de bandeau.
///
/// Ne rend rien visuellement (`SizedBox.shrink`) : il se contente d'écouter le flux WS et d'utiliser
/// le messenger global ([appMessengerKey]) — le même que le push au premier plan. Best-effort :
/// toute erreur (messenger absent, conversation introuvable) est silencieuse, jamais bloquante.
class RealtimeBanner extends ConsumerStatefulWidget {
  const RealtimeBanner({super.key});

  @override
  ConsumerState<RealtimeBanner> createState() => _RealtimeBannerState();
}

class _RealtimeBannerState extends ConsumerState<RealtimeBanner> {
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(realtimeServiceProvider).events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(RealtimeEvent e) {
    if (e is! DmReceived) return;
    final msg = e.message;
    // Sans contenu (ancienne trame) on ne peut rien afficher d'utile → la pastille suffit.
    if (msg == null) return;
    // Mes propres messages (multi-device / écho serveur) ne déclenchent pas de bandeau.
    if (msg.isMine) return;
    // Déjà dans CETTE conversation → le message est affiché dans le fil, pas de bandeau redondant.
    if (ref.read(activeConversationProvider) == e.conversationId) return;
    _showBanner(e.conversationId, msg);
  }

  /// Résout le nom/avatar de l'expéditeur via la liste des conversations (le WS ne porte que le
  /// `senderId`), puis affiche le bandeau et l'ouvre au tap sur le BON chat. Tolérant aux échecs.
  Future<void> _showBanner(String conversationId, DmMessage msg) async {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    ConversationSummary? summary;
    try {
      final convos = await ref.read(apiClientProvider).conversations();
      for (final c in convos) {
        if (c.id == conversationId) {
          summary = c;
          break;
        }
      }
    } catch (_) {
      // réseau : on affiche quand même un bandeau générique (sans nom) plutôt que rien.
    }
    if (!mounted) return;

    final senderName = summary?.otherName ?? t.newMessageSenderFallback;
    final title = t.newMessageBannerTitle(senderName);
    final body = msg.body;

    final messenger = appMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: HiColors.bgElevated2,
          duration: const Duration(seconds: 5),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              if (body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: HiColors.textSecondary, fontSize: 12.5)),
                ),
            ],
          ),
          action: summary == null
              ? null
              : SnackBarAction(
                  label: t.newMessageBannerOpen,
                  textColor: HiColors.brandPrimary,
                  onPressed: () => _openChat(summary!),
                ),
        ),
      );
  }

  /// Ouvre directement le fil de discussion concerné (sur le navigator global), en repassant par la
  /// racine pour ne pas empiler les écrans. No-op si le navigator n'est pas monté.
  void _openChat(ConversationSummary c) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    appMessengerKey.currentState?.hideCurrentSnackBar();
    nav.push(MaterialPageRoute<void>(
      builder: (_) => ChatScreen(conversationId: c.id, otherUserId: c.otherUserId, otherName: c.otherName),
    ));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
