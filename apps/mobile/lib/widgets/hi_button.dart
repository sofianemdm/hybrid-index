import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Bouton héro : gradient marque + glow léger. Affiche un spinner si `loading`.
class HiButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const HiButton({super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: HiColors.brandGradient,
          borderRadius: BorderRadius.circular(HiRadius.md),
          boxShadow: enabled
              ? [const BoxShadow(color: Color(0x593DE1FF), blurRadius: 20, spreadRadius: -2)]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(HiRadius.md),
            onTap: enabled ? onPressed : null,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: HiColors.textOnBrand),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: HiColors.textOnBrand,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton secondaire : contour, fond transparent.
class HiButtonSecondary extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const HiButtonSecondary({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: HiColors.strokeStrong),
        foregroundColor: HiColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HiRadius.md)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
