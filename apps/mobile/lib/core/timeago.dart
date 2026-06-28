import '../l10n/app_localizations.dart';

/// Temps relatif localisé (« à l'instant », « il y a 3 h », « il y a 2 j ») pour les cartes de feed.
/// Volontairement compact (min / h / j) ; au-delà de quelques jours, on retombe sur les jours.
String timeAgo(AppLocalizations t, DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return t.timeAgoNow;
  if (diff.inMinutes < 60) return t.timeAgoMinutes(diff.inMinutes);
  if (diff.inHours < 24) return t.timeAgoHours(diff.inHours);
  return t.timeAgoDays(diff.inDays);
}
