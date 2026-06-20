import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as gsw;

import '../../core/env.dart';

/// Bouton de connexion Google (Web) : rend le bouton officiel Google Identity Services et
/// remonte l'idToken une fois l'utilisateur authentifié.
class GoogleSignInButton extends StatefulWidget {
  final void Function(String idToken) onToken;
  final void Function(String message) onError;
  const GoogleSignInButton({super.key, required this.onToken, required this.onError});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  final GoogleSignIn _gsi = GoogleSignIn(clientId: Env.googleClientId, scopes: const ['email', 'profile']);
  StreamSubscription<GoogleSignInAccount?>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _gsi.onCurrentUserChanged.listen((account) async {
      if (account == null) return;
      try {
        final auth = await account.authentication;
        final idToken = auth.idToken;
        if (idToken != null) {
          widget.onToken(idToken);
        } else {
          widget.onError('idToken Google manquant.');
        }
      } catch (e) {
        widget.onError('$e');
      }
    });
    _gsi.signInSilently();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plugin = GoogleSignInPlatform.instance as gsw.GoogleSignInPlugin;
    return plugin.renderButton();
  }
}
