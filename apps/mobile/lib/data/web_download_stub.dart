import 'dart:typed_data';

/// Stub mobile/desktop : le téléchargement navigateur n'existe pas ici.
/// (Sur mobile natif, on utiliserait un partage de fichier ; hors périmètre démo Web.)
Future<bool> downloadBytes(Uint8List bytes, String filename) async => false;
