import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';

/// Regex email simple (aligné sur la spec design §4) : un @, un point, pas d'espace.
final RegExp kEmailRegExp = RegExp(r'^\S+@\S+\.\S+$');

/// Regex pseudo : 3 à 20 caractères, alphanumériques + underscore, sans espace.
final RegExp kUsernameRegExp = RegExp(r'^[A-Za-z0-9_]{3,20}$');

/// Champ de saisie designé pour l'auth (label au-dessus, prefix icône, focus cyan + glow,
/// message d'aide/erreur sous le champ avec hauteur réservée pour éviter le saut de layout).
/// S'aligne sur `inputDecorationTheme` mais rend le contour/glow lui-même pour l'état focus.
class HiAuthField extends StatefulWidget {
  const HiAuthField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final IconData? prefixIcon;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  State<HiAuthField> createState() => _HiAuthFieldState();
}

class _HiAuthFieldState extends State<HiAuthField> {
  late final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus != _focused) {
        setState(() => _focused = _focus.hasFocus);
        if (_focus.hasFocus) HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final Color borderColor = hasError
        ? HiColors.error
        : _focused
            ? HiColors.brandPrimary
            : HiColors.strokeSubtle;
    final Color iconColor = hasError
        ? HiColors.error
        : _focused
            ? HiColors.brandPrimary
            : HiColors.textTertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: HiType.label.copyWith(color: HiColors.textSecondary)),
        const SizedBox(height: HiSpace.sm),
        AnimatedContainer(
          duration: HiMotion.fast,
          curve: HiMotion.enter,
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: HiColors.bgElevated2,
            borderRadius: BorderRadius.circular(HiRadius.md),
            border: Border.all(color: borderColor, width: _focused || hasError ? 1.5 : 1),
            boxShadow: _focused && !hasError ? HiShadow.glowBrand(0.15) : null,
          ),
          child: Row(
            children: [
              if (widget.prefixIcon != null)
                Padding(
                  padding: const EdgeInsets.only(left: HiSpace.md, right: HiSpace.sm),
                  child: Icon(widget.prefixIcon, size: 20, color: iconColor),
                )
              else
                const SizedBox(width: HiSpace.md),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  obscureText: widget.obscure,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  autofillHints: widget.autofillHints,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: HiColors.brandPrimary,
                  style: HiType.body.copyWith(color: HiColors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    hintText: widget.hint,
                    hintStyle: HiType.body.copyWith(color: HiColors.textTertiary),
                  ),
                ),
              ),
              if (widget.suffix != null) widget.suffix!,
            ],
          ),
        ),
        // Hauteur réservée pour le message (aide/erreur) → pas de saut de layout.
        Padding(
          padding: const EdgeInsets.only(top: HiSpace.xs, left: HiSpace.xs),
          child: Text(
            hasError ? widget.errorText! : (widget.helper ?? ''),
            style: HiType.caption.copyWith(
              color: hasError ? HiColors.error : HiColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bouton œil afficher/masquer (48×48, cible tactile AA), à passer en `suffix` de [HiAuthField].
class HiPasswordToggle extends StatelessWidget {
  const HiPasswordToggle({
    super.key,
    required this.obscured,
    required this.onToggle,
    required this.showLabel,
    required this.hideLabel,
  });

  final bool obscured;
  final VoidCallback onToggle;
  final String showLabel;
  final String hideLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: obscured ? showLabel : hideLabel,
      button: true,
      child: IconButton(
        onPressed: onToggle,
        splashRadius: 22,
        icon: AnimatedSwitcher(
          duration: HiMotion.fast,
          child: Icon(
            obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            key: ValueKey(obscured),
            size: 20,
            color: HiColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Bandeau d'erreur/succès inline en haut du formulaire (jamais de SnackBar pour l'auth).
/// Apparition en AnimatedSize + fade ; `liveRegion` pour l'annonce lecteur d'écran.
class HiFormBanner extends StatelessWidget {
  const HiFormBanner({super.key, this.message, this.success = false});

  final String? message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final visible = message != null && message!.isNotEmpty;
    final Color base = success ? HiColors.success : HiColors.error;
    return AnimatedSize(
      duration: HiMotion.fast,
      curve: HiMotion.enter,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: HiMotion.fast,
        opacity: visible ? 1 : 0,
        child: !visible
            ? const SizedBox(width: double.infinity, height: 0)
            : Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: HiSpace.md),
                padding: const EdgeInsets.all(HiSpace.md),
                decoration: BoxDecoration(
                  color: base.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(HiRadius.sm),
                  border: Border.all(color: base.withValues(alpha: 0.40)),
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(success ? Icons.check_circle_outline : Icons.error_outline,
                          size: 20, color: base),
                      const SizedBox(width: HiSpace.sm),
                      Expanded(
                        child: Text(message!,
                            style: HiType.body.copyWith(color: HiColors.textPrimary)),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Ligne de choix (sexe / matériel) : label + chips sélectionnables, calée sur le design system.
class HiChoiceRow extends StatelessWidget {
  const HiChoiceRow({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: HiType.label.copyWith(color: HiColors.textSecondary)),
        const SizedBox(height: HiSpace.sm),
        Wrap(
          spacing: HiSpace.sm,
          runSpacing: HiSpace.sm,
          children: options.entries.map((e) {
            final active = e.key == value;
            return ChoiceChip(
              label: Text(e.value),
              selected: active,
              showCheckmark: false,
              selectedColor: HiColors.brandPrimary,
              backgroundColor: HiColors.bgElevated2,
              labelStyle: HiType.label.copyWith(
                color: active ? HiColors.textOnBrand : HiColors.textSecondary,
              ),
              side: BorderSide(color: active ? Colors.transparent : HiColors.strokeSubtle),
              onSelected: enabled
                  ? (_) {
                      HapticFeedback.selectionClick();
                      onChanged(e.key);
                    }
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Sélecteur de date de naissance (ouvre le date picker), présenté comme un champ [HiAuthField].
class HiDateField extends StatelessWidget {
  const HiDateField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.value,
    required this.onTap,
    this.errorText,
    this.enabled = true,
  });

  final String label;
  final String placeholder;
  final DateTime? value;
  final VoidCallback onTap;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    final filled = value != null;
    final text = filled ? value!.toIso8601String().split('T').first : placeholder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: HiType.label.copyWith(color: HiColors.textSecondary)),
        const SizedBox(height: HiSpace.sm),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(HiRadius.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: HiSpace.md),
            decoration: BoxDecoration(
              color: HiColors.bgElevated2,
              borderRadius: BorderRadius.circular(HiRadius.md),
              border: Border.all(
                color: hasError ? HiColors.error : HiColors.strokeSubtle,
                width: hasError ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.cake_outlined,
                    size: 20, color: hasError ? HiColors.error : HiColors.textTertiary),
                const SizedBox(width: HiSpace.sm),
                Expanded(
                  child: Text(text,
                      style: HiType.body.copyWith(
                          color: filled ? HiColors.textPrimary : HiColors.textTertiary)),
                ),
                Icon(Icons.expand_more, size: 20, color: HiColors.textTertiary),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: HiSpace.xs, left: HiSpace.xs),
          child: Text(
            hasError ? errorText! : '',
            style: HiType.caption.copyWith(color: HiColors.error),
          ),
        ),
      ],
    );
  }
}

/// Wordmark « ATHLETE LEAGUE » (pastille marque + texte), commun aux 2 écrans d'auth.
class AuthWordmark extends StatelessWidget {
  const AuthWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: HiColors.brandGradient,
            boxShadow: HiShadow.glowBrand(0.3),
          ),
          child: Icon(Icons.bolt_rounded, color: HiColors.textOnBrand, size: 36),
        ),
        const SizedBox(height: HiSpace.md),
        Text('ATHLETE LEAGUE',
            textAlign: TextAlign.center,
            style: HiType.displayL.copyWith(fontSize: 34, color: HiColors.textPrimary, letterSpacing: 1)),
      ],
    );
  }
}

/// Lien texte de bascule Connexion ↔ Inscription (sous le formulaire).
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text(label, style: HiType.bodyStrong.copyWith(color: HiColors.brandPrimary)),
      ),
    );
  }
}
