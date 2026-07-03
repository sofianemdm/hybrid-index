// Fichier WEB UNIQUEMENT (import conditionnel depuis web_download.dart) : dart:html y est
// légitime. `flutter analyze` traite les infos comme fatales en CI → on les neutralise ICI,
// avec cette justification. Migration package:web possible plus tard, sans urgence.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Téléchargement navigateur : crée un blob PNG et déclenche le téléchargement.
Future<bool> downloadBytes(Uint8List bytes, String filename) async {
  final blob = html.Blob(<Object>[bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = filename;
  anchor.click();
  html.Url.revokeObjectUrl(url);
  return true;
}
