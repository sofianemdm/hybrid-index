import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/session.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Feuille « Signaler un bug » (bêta) : un champ texte → POST /v1/feedback (stocké en base).
Future<void> showBugReportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // remonte au-dessus du clavier
    backgroundColor: HiColors.bgElevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(HiRadius.xxl))),
    builder: (_) => const _BugReportSheet(),
  );
}

class _BugReportSheet extends ConsumerStatefulWidget {
  const _BugReportSheet();

  @override
  ConsumerState<_BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends ConsumerState<_BugReportSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = AppLocalizations.of(context);
    final msg = _controller.text.trim();
    if (msg.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.bugReportTooShort)));
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(apiClientProvider).sendFeedback(msg, context: 'app');
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.bugReportThanks)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          HiSpace.lg, HiSpace.lg, HiSpace.lg, MediaQuery.of(context).viewInsets.bottom + HiSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report_rounded, color: HiColors.warn),
              const SizedBox(width: HiSpace.sm),
              Expanded(child: Text(t.bugReportTitle, style: HiType.titleM.copyWith(color: HiColors.textPrimary))),
            ],
          ),
          const SizedBox(height: HiSpace.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: t.bugReportHint,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: HiSpace.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: HiColors.brandPrimary,
                foregroundColor: HiColors.textOnBrand,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(t.bugReportSend),
              onPressed: _sending ? null : _send,
            ),
          ),
        ],
      ),
    );
  }
}
