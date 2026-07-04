// REPRO DIAGNOSTIC TEMPORAIRE (04/07, à supprimer) : exécute le VRAI code réseau de l'app
// (ApiClient.register + myProfile) en build web RELEASE, servi en MÊME ORIGINE sur :8094.
// Chaque étape/erreur est rapportée au collecteur /diag-report (fichier diag-report.jsonl)
// via le beacon — je lis le fichier pour connaître la cause exacte des échecs.
import 'data/api_client.dart';
import 'data/diag_beacon.dart';

Future<void> main() async {
  diagBeacon('repro-start', {});
  final api = ApiClient(baseUrl: 'http://localhost:8094');
  final stamp = DateTime.now().millisecondsSinceEpoch;
  try {
    final reg = await api.register({
      'email': 'repro$stamp@example.com',
      'password': 'motdepasse123',
      'displayName': 'Repro${stamp % 1000000}',
      'dateOfBirth': '1990-01-01',
      'sex': 'male',
      'equipmentPref': 'both',
    });
    diagBeacon('repro-register-ok', {'tokenLen': reg.token.length});
    api.setToken(reg.token);
    final p = await api.myProfile();
    diagBeacon('repro-result', {
      'outcome': p == null ? 'PROFILE_NULL => ONBOARDING (CORRECT)' : 'PROFILE_PRESENT (inattendu)',
    });
  } on ApiException catch (e) {
    diagBeacon('repro-apiexception', {'code': e.code, 'status': e.status, 'message': e.message});
  } catch (e) {
    diagBeacon('repro-crash', {'errorType': e.runtimeType.toString(), 'error': '$e'});
  }
}
