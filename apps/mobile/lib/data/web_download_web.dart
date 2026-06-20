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
