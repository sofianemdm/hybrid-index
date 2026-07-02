import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/env.dart';
import '../../theme/tokens.dart';

/// Bouton de connexion Google (mobile/desktop) : déclenche le flux natif `signIn()`.
class GoogleSignInButton extends StatelessWidget {
  final void Function(String idToken) onToken;
  final void Function(String message) onError;
  const GoogleSignInButton({super.key, required this.onToken, required this.onError});

  Future<void> _signIn() async {
    try {
      // Sur Android/iOS, `clientId` est lu depuis google-services.json (client OAuth natif).
      // `serverClientId` = le client OAuth *Web* du même projet Firebase → l'idToken renvoyé a pour
      // audience ce client, que le backend vérifie (GOOGLE_CLIENT_ID). Les DEUX doivent être identiques.
      final gsi = GoogleSignIn(
        serverClientId: Env.googleClientId.isEmpty ? null : Env.googleClientId,
        scopes: const ['email', 'profile'],
      );
      final account = await gsi.signIn();
      if (account == null) return; // annulé
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken != null) {
        onToken(idToken);
      } else {
        onError('idToken Google manquant.');
      }
    } catch (e) {
      onError('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: HiColors.strokeStrong),
        foregroundColor: HiColors.textPrimary,
      ),
      icon: const Icon(Icons.account_circle_outlined),
      label: const Text('Continuer avec Google'),
      onPressed: _signIn,
    );
  }
}
