import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Bouton « Continuer avec Apple » — affiché UNIQUEMENT sur iOS/macOS natif (exigence Apple :
/// Sign in with Apple obligatoire dès qu'un autre login social est proposé sur l'App Store ;
/// inutile ailleurs). Style conforme aux guidelines Apple (noir, logo, coins arrondis).
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key, required this.onToken, required this.onError});

  /// Reçoit l'identityToken (JWT) à transmettre à l'api (/v1/auth/apple).
  final void Function(String identityToken) onToken;
  final void Function(String message) onError;

  /// Plateformes où le bouton existe (le plugin ne supporte que iOS/macOS pour l'app native).
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> _signIn() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final token = credential.identityToken;
      if (token == null || token.isEmpty) {
        onError('Connexion Apple : jeton manquant.');
        return;
      }
      onToken(token);
    } on SignInWithAppleAuthorizationException catch (e) {
      // Annulation utilisateur : silencieux (pas une erreur).
      if (e.code != AuthorizationErrorCode.canceled) onError(e.message);
    } catch (e) {
      onError('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!supported) return const SizedBox.shrink();
    return SignInWithAppleButton(
      onPressed: _signIn,
      style: SignInWithAppleButtonStyle.black,
      height: 44,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
    );
  }
}
