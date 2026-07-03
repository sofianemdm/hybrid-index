import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// OUTBOX : file d'attente locale des résultats de séance saisis HORS LIGNE.
///
/// Principe : si l'enregistrement échoue pour cause de réseau (NETWORK/TIMEOUT), le payload est
/// stocké sur l'appareil puis rejoué au retour du réseau (reprise d'app, retour au premier plan).
/// - SÛRETÉ : chaque payload garde son `idempotencyKey` d'origine → un double envoi ne crée
///   JAMAIS de doublon côté serveur (contrainte unique).
/// - DATE : heure de SYNCHRO stricte (décision produit 03/07) — le serveur horodate à la
///   réception, comme pour tout enregistrement (aucune porte ouverte à l'antidatage).
/// - Le score/Index n'est calculé qu'à la synchro (la notation vit côté serveur).
class Outbox {
  Outbox(this._api);

  final ApiClient _api;
  static const _kKey = 'outbox:results';

  /// Nombre d'éléments en attente (pour le badge UI). Mis à jour par enqueue/flush.
  static final ValueNotifier<int> pending = ValueNotifier<int>(0);

  static Future<List<Map<String, dynamic>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(items));
    pending.value = items.length;
  }

  /// Recharge le compteur au démarrage (badge correct dès l'ouverture).
  static Future<void> restoreCount() async {
    pending.value = (await _load()).length;
  }

  /// Met un résultat en attente. [wodId] + le payload COMPLET de POST /v1/results
  /// (rawResult, rxCompliant, idempotencyKey, distanceMeters…).
  Future<void> enqueue(String wodId, Map<String, dynamic> payload) async {
    final items = await _load();
    // Anti-doublon local : même idempotencyKey déjà en file → on ne rajoute pas.
    final key = payload['idempotencyKey'];
    if (key != null && items.any((e) => (e['payload'] as Map)['idempotencyKey'] == key)) return;
    items.add({'wodId': wodId, 'payload': payload});
    await _save(items);
  }

  /// Rejoue la file dans l'ordre. S'arrête au premier échec RÉSEAU (on retentera plus tard) ;
  /// une erreur MÉTIER (4xx : validation, borne physio…) retire l'élément (le rejouer ne
  /// changerait rien) — le résultat est perdu mais la file ne se bloque jamais.
  /// Retourne le nombre d'éléments synchronisés avec succès.
  Future<int> flush() async {
    var items = await _load();
    if (items.isEmpty) return 0;
    var synced = 0;
    while (items.isNotEmpty) {
      final item = items.first;
      try {
        await _api.logWodResult(item['wodId'] as String, Map<String, dynamic>.from(item['payload'] as Map));
        synced++;
        items = items.sublist(1);
        await _save(items);
      } on ApiException catch (e) {
        if (e.code == 'NETWORK' || e.code == 'TIMEOUT') break; // toujours hors ligne → plus tard
        debugPrint('[outbox] résultat rejeté par le serveur (${e.code}) — retiré de la file.');
        items = items.sublist(1);
        await _save(items);
      } catch (_) {
        break;
      }
    }
    return synced;
  }
}
