import 'package:intl/intl.dart';

/// Convertit un monthKey "2026-06" en libellé localisé « Juin 2026 » / « June 2026 ».
/// `locale` = ex. "fr" / "en" (Localizations.localeOf(context).toString()). Repli sûr sur le brut
/// si le format est inattendu (jamais d'exception en UI).
String formatMonthKey(String monthKey, String locale) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return monthKey;
  final label = DateFormat.yMMMM(locale).format(DateTime(year, month));
  // Majuscule initiale (les locales comme fr rendent « juin » en minuscule).
  return label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
}
