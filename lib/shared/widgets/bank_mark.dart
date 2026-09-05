import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/bank_brand.dart';

/// A white badge holding a bank or network logo fetched over the network.
///
/// It renders *nothing at all* when the image fails. That matters because
/// logo URLs are partly reconstructed from naming conventions and several
/// simply don't exist — without this the empty badge still painted, which is
/// what produced stray white boxes on card faces.
class LogoBadge extends StatefulWidget {
  final String url;
  final double logoHeight;
  final bool circular;

  const LogoBadge({
    super.key,
    required this.url,
    this.logoHeight = 14,
    this.circular = false,
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

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();

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
      child: Image.network(
        widget.url,
        height: widget.logoHeight,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) {
          // Collapse on the next frame — setState is illegal during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_failed) setState(() => _failed = true);
          });
          return const SizedBox.shrink();
        },
      ),
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
