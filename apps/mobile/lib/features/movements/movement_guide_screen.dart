import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_card.dart';
import 'movement_guide_content.dart';

/// Écran « Comment faire les mouvements ».
///
/// Reçoit une liste ORDONNÉE de libellés de mouvements (ids `movementId` OU noms libres tels
/// qu'écrits dans la prescription d'un WOD). Chaque libellé est résolu vers une fiche pédagogique
/// ([MovementGuide]) via [resolveMovementGuides] ; les libellés non résolus sont ignorés.
///
/// S'ouvre aussi en GLOSSAIRE GLOBAL (tous les mouvements connus) si `labels` est vide/non fourni.
///
/// Pour chaque mouvement : une carte avec le schéma SVG, « Comment faire » (steps), « Points clés »
/// (cues), « Erreurs fréquentes » (mistakes), « Version facile » (beginner). Langue = locale courante.
class MovementGuideScreen extends StatelessWidget {
  const MovementGuideScreen({super.key, this.labels = const [], this.title});

  /// Libellés des mouvements de la séance (ids ou noms libres). Vide ⇒ glossaire global.
  final List<String> labels;

  /// Titre de l'AppBar (nom de la séance). Défaut i18n si null.
  final String? title;

  /// Ouvre l'écran en route plein écran. Helper de lancement depuis les points d'accès.
  static Future<void> open(
    BuildContext context, {
    List<String> labels = const [],
    String? title,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MovementGuideScreen(labels: labels, title: title),
      ),
    );
  }

  /// Liste des fiches à afficher : résolues depuis `labels`, ou catalogue complet si vide.
  List<MovementGuide> _guidesFor() {
    if (labels.isEmpty) {
      // Glossaire global : tout le catalogue (ordre d'insertion = regroupement par famille).
      return movementGuides.values.toList(growable: false);
    }
    return resolveMovementGuides(labels);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final guides = _guidesFor();
    final isGlossary = labels.isEmpty;

    return Scaffold(
      backgroundColor: HiColors.bgBase,
      appBar: AppBar(
        backgroundColor: HiColors.bgBase,
        elevation: 0,
        title: Text(
          title ?? t.movementGuideTitle,
          style: HiType.titleM.copyWith(color: HiColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: HiColors.textSecondary),
      ),
      body: guides.isEmpty
          ? _EmptyState(isGlossary: isGlossary)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                HiSpace.gutter,
                HiSpace.md,
                HiSpace.gutter,
                HiSpace.xl,
              ),
              itemCount: guides.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: HiSpace.md),
              itemBuilder: (context, i) {
                if (i == 0) {
                  // Intro courte : rassurer le grand débutant.
                  return Padding(
                    padding: const EdgeInsets.only(bottom: HiSpace.xs),
                    child: Text(
                      t.movementGuideIntro,
                      style: HiType.body.copyWith(color: HiColors.textSecondary),
                    ),
                  );
                }
                return _MovementCard(guide: guides[i - 1], lang: lang);
              },
            ),
    );
  }
}

/// État vide : aucune fiche résolue (libellés inconnus) ou catalogue vide.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isGlossary});
  final bool isGlossary;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HiSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 48, color: HiColors.textTertiary),
            const SizedBox(height: HiSpace.md),
            Text(
              isGlossary ? t.movementGuideEmptyGlossary : t.movementGuideEmpty,
              textAlign: TextAlign.center,
              style: HiType.body.copyWith(color: HiColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une carte de mouvement : schéma + sections pédagogiques.
class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.guide, required this.lang});
  final MovementGuide guide;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final name = guide.nameIn(lang);
    final steps = guide.stepsIn(lang);
    final cues = guide.cuesIn(lang);
    final mistakes = guide.mistakesIn(lang);
    final beginner = guide.beginnerIn(lang);

    // a11y : la carte résume le mouvement (nom + nb d'étapes). Le détail visuel reste lisible
    // par le lecteur d'écran via les Text enfants ; le schéma décoratif est exclu.
    return Semantics(
      container: true,
      label: t.a11yMovementCard(name),
      child: HiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
            const SizedBox(height: HiSpace.sm),
            _Schematic(svgAsset: guide.svgAsset, label: name),
            if (steps.isNotEmpty) ...[
              const SizedBox(height: HiSpace.md),
              _Section(
                icon: Icons.format_list_numbered_rounded,
                label: t.movementGuideHowTo,
                child: _OrderedList(items: steps),
              ),
            ],
            if (cues.isNotEmpty) ...[
              const SizedBox(height: HiSpace.md),
              _Section(
                icon: Icons.verified_outlined,
                label: t.movementGuideKeyPoints,
                accent: HiColors.brandPrimary,
                child: _BulletList(items: cues, dotColor: HiColors.brandPrimary),
              ),
            ],
            if (mistakes.isNotEmpty) ...[
              const SizedBox(height: HiSpace.md),
              _Section(
                icon: Icons.warning_amber_rounded,
                label: t.movementGuideMistakes,
                accent: HiColors.warn,
                child: _BulletList(items: mistakes, dotColor: HiColors.warn),
              ),
            ],
            if (beginner.trim().isNotEmpty) ...[
              const SizedBox(height: HiSpace.md),
              _BeginnerBox(text: beginner, label: t.movementGuideEasyVersion),
            ],
          ],
        ),
      ),
    );
  }
}

/// Le schéma SVG du mouvement, sur un fond doux. Repli sur `_fallback.svg` si l'asset manque.
class _Schematic extends StatelessWidget {
  const _Schematic({required this.svgAsset, required this.label});
  final String svgAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        height: 160,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HiColors.bgElevated2,
          borderRadius: BorderRadius.circular(HiRadius.md),
          border: Border.all(color: HiColors.strokeSubtle),
        ),
        padding: const EdgeInsets.all(HiSpace.sm),
        child: _SvgOrFallback(svgAsset: svgAsset),
      ),
    );
  }
}

/// Charge le SVG demandé ; si l'asset n'existe pas dans le bundle, affiche `_fallback.svg`,
/// et si même le fallback manque, une icône neutre. Aucune exception ne remonte à l'UI.
class _SvgOrFallback extends StatefulWidget {
  const _SvgOrFallback({required this.svgAsset});
  final String svgAsset;

  @override
  State<_SvgOrFallback> createState() => _SvgOrFallbackState();
}

class _SvgOrFallbackState extends State<_SvgOrFallback> {
  static const String _fallbackAsset = 'assets/movements/_fallback.svg';
  late Future<String> _assetFuture;

  @override
  void initState() {
    super.initState();
    _assetFuture = _resolveAsset();
  }

  @override
  void didUpdateWidget(covariant _SvgOrFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.svgAsset != widget.svgAsset) {
      _assetFuture = _resolveAsset();
    }
  }

  /// Renvoie l'asset demandé s'il existe dans le bundle, sinon le fallback.
  Future<String> _resolveAsset() async {
    try {
      await rootBundle.load(widget.svgAsset);
      return widget.svgAsset;
    } catch (_) {
      return _fallbackAsset;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _assetFuture,
      builder: (context, snap) {
        final asset = snap.data;
        if (asset == null) {
          // Pendant la résolution : placeholder neutre (pas de spinner agressif).
          return const SizedBox.shrink();
        }
        return SvgPicture.asset(
          asset,
          fit: BoxFit.contain,
          placeholderBuilder: (_) =>
              Icon(Icons.fitness_center_rounded, size: 40, color: HiColors.textTertiary),
        );
      },
    );
  }
}

/// En-tête de section (icône + libellé en overline) + contenu.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.label,
    required this.child,
    this.accent,
  });
  final IconData icon;
  final String label;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? HiColors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: HiType.overline.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: HiSpace.sm),
        child,
      ],
    );
  }
}

/// Liste numérotée (étapes « comment faire »).
class _OrderedList extends StatelessWidget {
  const _OrderedList({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : HiSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}.',
                    style: HiType.bodyStrong.copyWith(color: HiColors.brandPrimary),
                  ),
                ),
                Expanded(
                  child: Text(
                    items[i],
                    style: HiType.body.copyWith(color: HiColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Liste à puces (points clés / erreurs).
class _BulletList extends StatelessWidget {
  const _BulletList({required this.items, required this.dotColor});
  final List<String> items;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : HiSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7, right: HiSpace.sm),
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Text(
                    items[i],
                    style: HiType.body.copyWith(color: HiColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Encadré « Version facile » : ton encourageant, accent marque doux.
class _BeginnerBox extends StatelessWidget {
  const _BeginnerBox({required this.text, required this.label});
  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HiSpace.sm),
      decoration: BoxDecoration(
        color: HiColors.brandPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(HiRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.spa_outlined, size: 16, color: HiColors.brandPrimary),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: HiType.overline.copyWith(color: HiColors.brandPrimary),
              ),
            ],
          ),
          const SizedBox(height: HiSpace.xs),
          Text(text, style: HiType.body.copyWith(color: HiColors.textPrimary)),
        ],
      ),
    );
  }
}
