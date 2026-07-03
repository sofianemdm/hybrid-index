import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Image réseau d'avatar avec cache DISQUE sur mobile : chaque avatar DiceBear est téléchargé
/// UNE fois puis affiché instantanément (fini le re-téléchargement à chaque rebuild/écran —
/// classements qui clignotent, data gaspillée). Sur le web, on garde `Image.network` (le cache
/// HTTP du navigateur fait déjà le travail — zéro changement de comportement).
class NetAvatarImage extends StatelessWidget {
  /// Posé à true par le harnais de tests (flutter_test_config) : CachedNetworkImage fait de l'IO
  /// disque/réseau réel (impossible en widget test) → on retombe sur Image.network, que
  /// l'environnement de test intercepte proprement (HTTP 400 immédiat → placeholder d'erreur).
  static bool testMode = false;

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext) placeholder;
  final Widget Function(BuildContext) error;

  const NetAvatarImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    required this.placeholder,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    // Décodage À LA TAILLE D'AFFICHAGE (× densité d'écran) : un avatar de 40 px n'a aucune
    // raison d'être décodé en 512×512 — sur les classements/fil (des dizaines d'avatars),
    // c'est le poste n°1 de mémoire image et de jank sur les téléphones modestes.
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final decodeW = width != null ? (width! * dpr).round() : null;
    if (kIsWeb || testMode) {
      return Image.network(
        url,
        width: width,
        height: height,
        cacheWidth: decodeW,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (ctx, _, __) => error(ctx),
        loadingBuilder: (ctx, child, progress) => progress == null ? child : placeholder(ctx),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      memCacheWidth: decodeW,
      fit: fit,
      // fadeIn court : l'avatar venu du cache apparaît quasi instantanément, sans clignotement.
      fadeInDuration: const Duration(milliseconds: 80),
      placeholder: (ctx, _) => placeholder(ctx),
      errorWidget: (ctx, _, __) => error(ctx),
    );
  }
}
