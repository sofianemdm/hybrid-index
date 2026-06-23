import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/models.dart';
import 'data/session.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'theme/tokens.dart';

/// Profil de l'utilisateur connecté (Index + radar). `null` = onboarding non terminé.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session.status != AuthStatus.loggedIn) return null;
  return ref.read(apiClientProvider).myProfile();
});

/// Avatar de l'utilisateur connecté (valeurs par défaut si jamais personnalisé).
final avatarProvider = FutureProvider<AvatarConfig>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session.status != AuthStatus.loggedIn) {
    return const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1);
  }
  return ref.read(apiClientProvider).getAvatar();
});

/// Série hebdomadaire (semaines actives). `null` si déconnecté. Tolérant : renvoie null en cas
/// d'erreur réseau (la flamme est non bloquante, jamais une raison d'échec d'écran).
final streakProvider = FutureProvider<StreakState?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session.status != AuthStatus.loggedIn) return null;
  try {
    return await ref.read(apiClientProvider).streak();
  } catch (_) {
    return null;
  }
});

/// Onglet actif de la coquille principale (0 = Accueil). Partagé pour pouvoir y revenir depuis
/// n'importe où (ex. après l'enregistrement d'une séance → retour à l'accueil).
final homeTabProvider = StateProvider<int>((ref) => 0);

/// Récap de la semaine en cours. Non bloquant (null si erreur/déconnecté).
final weeklyRecapProvider = FutureProvider<WeeklyRecap?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session.status != AuthStatus.loggedIn) return null;
  try {
    return await ref.read(apiClientProvider).weeklyRecap();
  } catch (_) {
    return null;
  }
});

/// Point d'entrée logique : décide quel écran montrer selon l'état d'auth + onboarding.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(sessionProvider.select((s) => s.status));

    switch (status) {
      case AuthStatus.loading:
        return const _Splash();
      case AuthStatus.loggedOut:
        return const AuthScreen();
      case AuthStatus.loggedIn:
        final profile = ref.watch(myProfileProvider);
        return profile.when(
          loading: () => const _Splash(),
          error: (e, _) => _ErrorScreen(message: '$e', onRetry: () => ref.invalidate(myProfileProvider)),
          data: (p) => p == null ? const OnboardingScreen() : const HomeShell(),
        );
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('HYBRID INDEX',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3, color: HiColors.textPrimary)),
            const SizedBox(height: 20),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: HiColors.brandPrimary, strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorScreen({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(HiSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, color: HiColors.error, size: 40),
              const SizedBox(height: HiSpace.md),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: HiColors.textSecondary)),
              const SizedBox(height: HiSpace.lg),
              OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ),
        ),
      ),
    );
  }
}
