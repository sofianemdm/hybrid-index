import 'package:avatar_maker/avatar_maker.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Création / personnalisation de l'avatar via `avatar_maker` (Phase 1).
/// Customizer avec preview live ; persistance locale (SharedPreferences) gérée par le package.
/// Phase 2 : sauvegarde backend + affichage partout + dopamine.
class AvatarMakerScreen extends StatelessWidget {
  const AvatarMakerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forge ton athlète'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text('Terminé', style: HiType.button.copyWith(color: HiColors.brandPrimary)),
          ),
        ],
      ),
      body: const SafeArea(child: AvatarMakerCustomizer()),
    );
  }
}
