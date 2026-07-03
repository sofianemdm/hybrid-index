import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/env.dart';
import '../data/session.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import '../widgets/hi_button.dart';

/// Garde de MISE À JOUR FORCÉE : au démarrage, compare le numéro de build de l'app
/// (`--dart-define=BUILD_NUMBER`, posé par le workflow APK/AAB) au minimum supporté publié par
/// l'api (`GET /v1/meta/app`, piloté par la variable d'env APP_MIN_BUILD côté serveur).
/// Build trop vieux → écran bloquant « Mets à jour l'app » avec lien vers la fiche du store.
///
/// Sans effet tant que : BUILD_NUMBER absent (dev/web/tests → 0), api injoignable (best-effort :
/// on ne bloque JAMAIS un utilisateur hors ligne), ou APP_MIN_BUILD non posé côté serveur (0).
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  String? _storeUrl; // non-null = mise à jour obligatoire

  @override
  void initState() {
    super.initState();
    if (Env.buildNumber > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    try {
      final meta = await ref.read(apiClientProvider).appMeta();
      if (!mounted) return;
      if (meta.minBuild > Env.buildNumber) {
        setState(() => _storeUrl = meta.storeUrl);
      }
    } catch (_) {
      // Injoignable (hors ligne, api down) → on laisse entrer : la mise à jour forcée est un
      // outil d'exploitation, jamais un mur devant un utilisateur sans réseau.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_storeUrl == null) return widget.child;
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HiColors.bgBase,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(HiSpace.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.system_update_rounded, color: HiColors.brandPrimary, size: 56),
                  const SizedBox(height: HiSpace.lg),
                  Text(t.updateRequiredTitle,
                      textAlign: TextAlign.center,
                      style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
                  const SizedBox(height: HiSpace.sm),
                  Text(t.updateRequiredBody,
                      textAlign: TextAlign.center,
                      style: HiType.body.copyWith(color: HiColors.textSecondary)),
                  const SizedBox(height: HiSpace.xl),
                  HiButton(
                    label: t.updateRequiredCta,
                    icon: Icons.open_in_new_rounded,
                    onPressed: () =>
                        launchUrl(Uri.parse(_storeUrl!), mode: LaunchMode.externalApplication),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
