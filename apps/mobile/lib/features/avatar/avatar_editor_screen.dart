import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../l10n/app_localizations.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/hi_button.dart';

/// Éditeur d'avatar : peau, cheveux (style + couleur), barbe. Création en quelques secondes.
class AvatarEditorScreen extends ConsumerStatefulWidget {
  const AvatarEditorScreen({super.key});

  @override
  ConsumerState<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends ConsumerState<AvatarEditorScreen> {
  AvatarConfig _config = const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1);
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await ref.read(apiClientProvider).getAvatar();
      setState(() {
        _config = a;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 72,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 400000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).avatarImageTooLarge)),
          );
        }
        return;
      }
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (mounted) setState(() => _config = _config.copyWith(photoData: dataUrl));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).updateAvatar(_config);
      ref.invalidate(avatarProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final rank = ref.watch(myProfileProvider).value?.index.rank ?? 'rookie';
    return Scaffold(
      appBar: AppBar(title: Text(t.avatarTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: HiColors.brandPrimary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(HiSpace.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: HiAvatar(config: _config, rank: rank, size: 160)),
                      const SizedBox(height: HiSpace.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.photo_camera_outlined, size: 18),
                            label: Text(_config.photoData == null ? t.avatarAddPhoto : t.avatarChangePhoto),
                          ),
                          if (_config.photoData != null) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => setState(() => _config = _config.copyWith(clearPhoto: true)),
                              child: Text(t.avatarRemove, style: HiType.button.copyWith(color: HiColors.error)),
                            ),
                          ],
                        ],
                      ),
                      if (_config.photoData != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(t.avatarPhotoHidesDrawn,
                              textAlign: TextAlign.center,
                              style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                        ),
                      const SizedBox(height: HiSpace.lg),
                      _label(t.avatarSkin),
                      _swatches(
                        AvatarPalettes.skin,
                        _config.skinTone,
                        (i) => setState(() => _config = _config.copyWith(skinTone: i)),
                      ),
                      const SizedBox(height: HiSpace.lg),
                      _label(t.avatarHairColor),
                      _swatches(
                        AvatarPalettes.hair,
                        _config.hairColor,
                        (i) => setState(() => _config = _config.copyWith(hairColor: i)),
                      ),
                      const SizedBox(height: HiSpace.lg),
                      _label(t.avatarHaircut),
                      _chips(
                        AvatarPalettes.hairStyleLabels,
                        _config.hairStyle,
                        (i) => setState(() => _config = _config.copyWith(hairStyle: i)),
                      ),
                      const SizedBox(height: HiSpace.lg),
                      _label(t.avatarBeard),
                      _chips(
                        AvatarPalettes.beardStyleLabels,
                        _config.beardStyle ?? 0,
                        (i) => setState(() => _config = _config.copyWith(beardStyle: i, clearBeard: i == 0)),
                      ),
                      const SizedBox(height: HiSpace.lg),
                      _label(t.avatarBackground),
                      _swatches(
                        AvatarPalettes.background,
                        _config.background,
                        (i) => setState(() => _config = _config.copyWith(background: i)),
                      ),
                      const SizedBox(height: HiSpace.xl),
                      HiButton(label: t.avatarSave, loading: _saving, onPressed: _save),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: HiSpace.sm),
        child: Text(t, style: HiType.overline.copyWith(color: HiColors.textSecondary)),
      );

  Widget _swatches(List<Color> colors, int selected, ValueChanged<int> onTap) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(colors.length, (i) {
        final active = i == selected;
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors[i],
              shape: BoxShape.circle,
              border: Border.all(color: active ? HiColors.brandPrimary : HiColors.strokeSubtle, width: active ? 3 : 1),
            ),
          ),
        );
      }),
    );
  }

  Widget _chips(List<String> labels, int selected, ValueChanged<int> onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(labels.length, (i) {
        final active = i == selected;
        return ChoiceChip(
          label: Text(labels[i]),
          selected: active,
          showCheckmark: false,
          selectedColor: HiColors.brandPrimary,
          backgroundColor: HiColors.bgElevated2,
          labelStyle: TextStyle(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w600),
          side: BorderSide(color: HiColors.strokeSubtle),
          onSelected: (_) => onTap(i),
        );
      }),
    );
  }
}
