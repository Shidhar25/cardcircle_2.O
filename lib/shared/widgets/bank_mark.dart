import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_theme.dart';
import '../models/bank_brand.dart';
import '../models/logo_assets.dart';

/// A bank or network logo fetched over the network, optionally sat on a
/// white badge.
///
/// It renders *nothing at all* when the image fails. That matters because
/// logo URLs are partly reconstructed from naming conventions and several
/// simply don't exist — without this the empty badge still painted, which is
/// what produced stray white boxes on card faces.
class LogoBadge extends StatefulWidget {
  final String url;
  final double logoHeight;
  final bool circular;

  /// Whether to sit the logo on a white chip.
  ///
  /// A bank logo can be any colour, so the chip is what keeps it legible
  /// over a card face it might otherwise vanish into. A network mark from
  /// `network_logo.url` is already exported with a transparent background —
  /// often white artwork meant for a dark card — and the same white chip
  /// would swallow it whole rather than showing it. Network marks pass
  /// `false` here for that reason; bank logos keep the default.
  final bool background;

  const LogoBadge({
    super.key,
    required this.url,
    this.logoHeight = 14,
    this.circular = false,
    this.background = true,
  });

  @override
  State<LogoBadge> createState() => _LogoBadgeState();
}

class _LogoBadgeState extends State<LogoBadge> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant LogoBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _failed = false;
  }

  /// Marks the badge dead, so the white container stops painting too.
  ///
  /// Drawing nothing is the whole contract of this widget — a logo that
  /// fails must take its badge with it, or the card face is left with an
  /// empty white box in the corner.
  Widget _giveUp() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_failed) setState(() => _failed = true);
    });
    return const SizedBox.shrink();
  }

  Widget _buildLogo(String url, double logoHeight) {
    final bool isSvg =
        url.toLowerCase().endsWith('.svg') || url.toLowerCase().contains('.svg');
    final bool isNetwork =
        url.startsWith('http://') || url.startsWith('https://');

    if (isSvg) {
      // Both SVG paths need the same failure handling the raster ones have.
      // Without it a 404 or a malformed file throws instead of degrading,
      // and the badge keeps painting its white box around nothing — the
      // exact bug this widget exists to prevent.
      if (isNetwork) {
        return SvgPicture.network(
          url,
          height: logoHeight,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => const SizedBox.shrink(),
          errorBuilder: (_, _, _) => _giveUp(),
        );
      } else {
        final String assetPath =
            url.startsWith('assets/') ? url : 'assets/$url';
        return SvgPicture.asset(
          assetPath,
          height: logoHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _giveUp(),
        );
      }
    } else {
      if (isNetwork) {
        return Image.network(
          url,
          height: logoHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _giveUp(),
        );
      } else {
        final String assetPath =
            url.startsWith('assets/') ? url : 'assets/$url';
        return Image.asset(
          assetPath,
          height: logoHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _giveUp(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();

    // Bundled marks are drawn for a dark card face — most of them are
    // white. The chip below is white too, so it would swallow them whole;
    // they go straight onto the card instead. Same reasoning for anything
    // that explicitly opted out of the chip via [background].
    if (LogoAssets.isBundled(widget.url) || !widget.background) {
      return _buildLogo(widget.url, widget.logoHeight);
    }

    return Container(
      padding: widget.circular
          ? const EdgeInsets.all(6)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        shape: widget.circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: widget.circular ? null : BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildLogo(widget.url, widget.logoHeight),
    );
  }
}

/// The issuer's monogram — the last-resort mark on a card face.
///
/// Logos themselves now come from the catalog (`bank_logo.url`), rendered by
/// [LogoBadge]. This is what shows when a card has no logo URL or the image
/// fails: initials always render, so the corner is never empty and nothing
/// here can 404 or block on a request.
class BankMark extends StatelessWidget {
  final String bankId;
  final String bankName;
  final double size;
  final Color color;

  const BankMark({
    super.key,
    required this.bankId,
    required this.bankName,
    this.size = 16,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) =>
      _Monogram(text: _initials, size: size, color: color);

  String get _initials {
    final fromName = bankInitials(bankName);
    return fromName.isNotEmpty ? fromName : bankInitials(bankId);
  }
}

class _Monogram extends StatelessWidget {
  final String text;
  final double size;
  final Color color;

  const _Monogram({
    required this.text,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: AppText.mono(size * 0.78, ls: 1.2, w: FontWeight.w700, c: color),
    );
  }
}
