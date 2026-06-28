import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'hi_button.dart';

/// État d'erreur designé et RÉUTILISABLE : icône cerclée + message lisible + bouton « Réessayer ».
///
/// Règle projet : on n'affiche JAMAIS un `Text('$e')` brut à l'utilisateur. Toute erreur passe
/// par ce widget avec un message localisable. Le libellé du message et du bouton viennent de
/// l'i18n (AppLocalizations) ; on peut les surcharger par [message] / [retryLabel] si besoin.
///
/// Usage typique dans un FutureBuilder / état de chargement :
/// ```dart
/// if (snapshot.hasError) {
///   return ErrorRetry(onRetry: _load); // message générique localisé par défaut
/// }
/// ```
class ErrorRetry extends StatelessWidget {
  /// Message à afficher. Si null, on utilise un message générique localisé.
  /// IMPORTANT : passer un message DÉJÀ traduit (jamais l'exception brute).
  final String? message;

  /// Appelé au tap sur « Réessayer ». Si null, le bouton est masqué.
  final VoidCallback? onRetry;

  /// Libellé du bouton. Si null, « Réessayer » (localisé).
  final String? retryLabel;

  /// Icône d'en-tête (par défaut : pas de réseau).
  final IconData icon;

  /// Variante compacte (sans cercle d'icône, padding réduit) pour les petits encarts.
  final bool compact;

  const ErrorRetry({
    super.key,
    this.message,
    this.onRetry,
    this.retryLabel,
    this.icon = Icons.cloud_off_rounded,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = message ?? l10n.commonGenericError;
    final retry = retryLabel ?? l10n.commonRetry;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? HiSpace.md : HiSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (compact)
              Icon(icon, color: HiColors.error, size: 32)
            else
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: HiColors.bgElevated2,
                  shape: BoxShape.circle,
                  border: Border.all(color: HiColors.strokeSubtle),
                ),
                child: Icon(icon, color: HiColors.error, size: 44),
              ),
            SizedBox(height: compact ? HiSpace.sm : HiSpace.lg),
            Text(
              text,
              textAlign: TextAlign.center,
              style: HiType.body.copyWith(color: HiColors.textSecondary),
            ),
            if (onRetry != null) ...[
              SizedBox(height: compact ? HiSpace.md : HiSpace.lg),
              SizedBox(
                width: compact ? null : 260,
                child: compact
                    ? HiButtonSecondary(label: retry, icon: Icons.refresh_rounded, onPressed: onRetry)
                    : HiButton(label: retry, icon: Icons.refresh_rounded, onPressed: onRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
