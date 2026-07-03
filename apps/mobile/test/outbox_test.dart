import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hybrid_index/data/api_client.dart';
import 'package:hybrid_index/data/outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OUTBOX — la file hors-ligne ne perd ni ne duplique jamais une séance :
/// rejouée au retour du réseau, stoppée si toujours hors ligne, purgée sur rejet métier (4xx).
void main() {
  ApiClient api(MockClient c) => ApiClient(client: c, baseUrl: 'http://t');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('enqueue puis flush : envoyée une fois, file vidée', () async {
    // Succès simulé : 200 minimal accepté par logWodResult (Map).
    final okClient = MockClient((r) async => http.Response(jsonEncode({'unlockedBadges': []}), 200));

    final box = Outbox(api(okClient));
    await box.enqueue('fran', {'rawResult': 245, 'idempotencyKey': 'k1'});
    await box.enqueue('fran', {'rawResult': 245, 'idempotencyKey': 'k1'}); // doublon local ignoré
    expect(Outbox.pending.value, 1);
    final synced = await box.flush();
    expect(synced, 1);
    expect(Outbox.pending.value, 0);
  });

  test('toujours hors ligne : la file reste intacte (retentera plus tard)', () async {
    final down = MockClient((r) async => throw Exception('no network'));
    final box = Outbox(api(down));
    await box.enqueue('fran', {'rawResult': 245, 'idempotencyKey': 'k2'});
    final synced = await box.flush();
    expect(synced, 0);
    expect(Outbox.pending.value, 1); // rien perdu
  });

  test('rejet métier (422) : élément retiré, la file ne se bloque pas', () async {
    final reject = MockClient((r) async => http.Response(
        jsonEncode({'error': {'code': 'WOD_RESULT_OUT_OF_BOUNDS', 'message': 'borne'}}), 422));
    final box = Outbox(api(reject));
    await box.enqueue('fran', {'rawResult': 1, 'idempotencyKey': 'k3'});
    final synced = await box.flush();
    expect(synced, 0);
    expect(Outbox.pending.value, 0); // purgé (le rejouer ne changerait rien)
  });
}
