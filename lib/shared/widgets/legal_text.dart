import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/remote_config.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme/app_theme.dart';
import 'app_snackbar.dart';

/// A line of copy with "Terms of Service" and "Privacy Policy" as live
/// links.
///
/// Both URLs come from `GET /bootstrap/config` (`legal.termsUrl`,
/// `legal.privacyUrl`), so they can be repointed without a release — which
/// matters, because the ones in the config today are placeholders pointing
/// at the site root.
///
/// A term with no URL at all renders as plain text rather than a tappable
/// span — a dead link that silently does nothing is worse than text, since
/// the user cannot tell whether they mis-tapped or the app is broken. Note
/// that a *blank* server value is not "no URL": `RemoteConfig.text` treats
/// blank as unset and falls back to the bundled default, so clearing the
/// field server-side leaves the link working rather than stripping the
/// user's route to the terms.
class LegalText extends StatefulWidget {
  /// Copy containing the two link phrases verbatim. Anything not matched is
  /// rendered as-is.
  final String text;

  final double size;
  final Color color;
  final TextAlign align;

  const LegalText({
    super.key,
    required this.text,
    this.size = 12.5,
    this.color = AppColors.textDim,
    this.align = TextAlign.start,
  });

  /// The phrases turned into links, each with the config key holding its
  /// URL. Longest first, so "Terms of Service" is matched before "Terms".
  static const List<(String, String)> _links = [
    ('Terms of Service', 'legal.termsUrl'),
    ('Privacy Policy', 'legal.privacyUrl'),
    ('Terms', 'legal.termsUrl'),
    ('Privacy', 'legal.privacyUrl'),
  ];

  @override
  State<LegalText> createState() => _LegalTextState();
}

class _LegalTextState extends State<LegalText> {
  /// One recogniser per link, created on first use and kept for the life of
  /// the widget.
  ///
  /// Deliberately *not* rebuilt per frame: disposing a recogniser during
  /// build kills it mid-gesture if a rebuild lands while a finger is down.
  /// Reusing them means the URL cannot be captured at construction either,
  /// so each tap reads the current config value — which is also what makes
  /// a config refresh take effect without rebuilding anything.
  final Map<String, TapGestureRecognizer> _recognisers = {};

  TapGestureRecognizer _recogniserFor(String configKey, String label) {
    return _recognisers.putIfAbsent(
      configKey,
      () =>
          TapGestureRecognizer()
            ..onTap = () => _open(config.text(configKey).trim(), label),
    );
  }

  @override
  void dispose() {
    for (final r in _recognisers.values) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _open(String url, String label) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    if (uri == null) {
      messenger.showError('Could not open the $label.');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) messenger.showError('Could not open the $label.');
    } catch (e, stack) {
      LoggerService.error('Failed to open $url', e, stack);
      messenger.showError('Could not open the $label.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = AppText.sans(widget.size, color: widget.color, height: 1.55);
    final linkStyle = base.copyWith(
      color: AppColors.gold,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.gold.withValues(alpha: 0.5),
    );

    final spans = <InlineSpan>[];
    var rest = widget.text;

    while (rest.isNotEmpty) {
      // Find whichever link phrase appears earliest in what's left.
      (int, String, String)? next;
      for (final (phrase, key) in LegalText._links) {
        final at = rest.indexOf(phrase);
        if (at == -1) continue;
        if (next == null || at < next.$1) next = (at, phrase, key);
      }

      if (next == null) {
        spans.add(TextSpan(text: rest, style: base));
        break;
      }

      final (at, phrase, key) = next;
      if (at > 0) {
        spans.add(TextSpan(text: rest.substring(0, at), style: base));
      }

      final url = config.text(key).trim();
      if (url.isEmpty) {
        // No destination configured — plain text, not a dead link.
        spans.add(TextSpan(text: phrase, style: base));
      } else {
        spans.add(
          TextSpan(
            text: phrase,
            style: linkStyle,
            recognizer: _recogniserFor(key, phrase),
          ),
        );
      }

      rest = rest.substring(at + phrase.length);
    }

    return Text.rich(TextSpan(children: spans), textAlign: widget.align);
  }
}
