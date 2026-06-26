import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/locale/l10n_extension.dart';
import '../../../core/share/widget_to_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'share_question_card.dart';

/// A visible "share" pill shown beneath the question (under the vote panel on
/// the daily). Tapping it renders the question as a branded [QuestionShareCard]
/// image and opens the platform share sheet (WhatsApp, Messenger, SMS, email,
/// Stories…) with that image plus a short Debatly signoff as the accompanying
/// text.
///
/// The image makes the share feel intentional (and recognisably "Debatly") rather
/// than a bare line of text; the same poster render doubles as store-screenshot
/// art. If rendering the card fails for any reason we fall back to sharing the
/// question as plain text, so the button never dead-ends.
///
/// Styled as a quiet, outlined hairline pill so it reads as an intentional
/// secondary action without competing with the glowing "go deeper" CTA below.
///
/// Only the question's own text is shared — never a locked teaser — so the
/// caller renders this strictly for readable questions.
class ShareQuestionButton extends StatefulWidget {
  const ShareQuestionButton({super.key, required this.questionText});

  /// The full text of the question currently on screen.
  final String questionText;

  @override
  State<ShareQuestionButton> createState() => _ShareQuestionButtonState();
}

class _ShareQuestionButtonState extends State<ShareQuestionButton> {
  /// True while the card is being rendered / the share sheet is being prepared,
  /// so a second tap can't fire a parallel render.
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    final text = widget.questionText.trim();
    if (text.isEmpty) return;

    // Capture everything that needs a live BuildContext BEFORE the first await,
    // so we never touch a possibly-unmounted context afterwards.
    final l10n = context.l10n;
    final ui.FlutterView view = View.of(context);
    // iPad presents the share sheet as a popover anchored to the tapped widget;
    // without an origin rect it throws there. Derive it from this button's box
    // so the sheet points at the pill (harmless/ignored on phones).
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    setState(() => _busy = true);
    try {
      final params = await _buildShareParams(
        text: text,
        l10n: l10n,
        view: view,
        origin: origin,
      );
      await SharePlus.instance.share(params);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Builds the share payload: the branded image card plus the signoff text,
  /// degrading to text-only if the card can't be rendered/encoded.
  Future<ShareParams> _buildShareParams({
    required String text,
    required AppLocalizations l10n,
    required ui.FlutterView view,
    required Rect? origin,
  }) async {
    final message = l10n.shareMessage(text);
    try {
      final png = await renderWidgetToPng(
        child: QuestionShareCard(
          questionText: text,
          tagline: l10n.shareCardTagline,
        ),
        logicalSize: const Size(360, 640),
        view: view,
      );
      if (png != null) {
        return ShareParams(
          text: message,
          subject: l10n.shareSubject,
          sharePositionOrigin: origin,
          files: [
            XFile.fromData(
              png,
              mimeType: 'image/png',
              name: 'spark-question.png',
            ),
          ],
        );
      }
    } catch (e) {
      debugPrint('share card render failed, sharing text only: $e');
    }
    // Fallback: text-only share (the original behaviour).
    return ShareParams(
      text: message,
      subject: l10n.shareSubject,
      sharePositionOrigin: origin,
    );
  }

  static const _radius = BorderRadius.all(Radius.circular(30));

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.shareTooltip,
      child: Tooltip(
        message: context.l10n.shareTooltip,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: _radius,
            side: BorderSide(color: context.colors.hairline),
          ),
          child: InkWell(
            borderRadius: _radius,
            onTap: _busy ? null : _share,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A small spinner replaces nothing — it slides in to the left
                  // of the label while the card renders, so the pill keeps its
                  // shape and the tap clearly "did something".
                  if (_busy) ...[
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.subtle,
                      ),
                    ),
                    const SizedBox(width: 9),
                  ],
                  Text(
                    context.l10n.shareLabel,
                    style: TextStyle(
                      color: context.colors.subtle,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
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
