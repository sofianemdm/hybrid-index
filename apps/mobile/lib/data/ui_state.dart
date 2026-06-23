import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onglet actif de la coquille principale (0 = Accueil). Partagé pour pouvoir y revenir depuis
/// n'importe où (ex. après l'enregistrement d'une séance → retour à l'accueil), et réinitialisé
/// à la déconnexion (sinon l'onglet « fuit » d'un compte à l'autre dans le même process).
/// Dans son propre fichier (sans dépendance) pour éviter un import circulaire avec app.dart.
final homeTabProvider = StateProvider<int>((ref) => 0);
