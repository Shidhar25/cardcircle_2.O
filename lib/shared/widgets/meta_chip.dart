import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// An icon + label chip that shrinks rather than overflowing.
///
/// Both labels it carries are free text from the backend and can be
/// arbitrarily long, so the text is always flexible and ellipsised; the
/// chip is only ever as wide as its parent allows.
class MetaChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color background;
  final String label;
  final Color labelColor;

  const MetaChip({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.chip),
        color: background,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: AppText.mono(
                9.5,
                ls: 0,
                w: FontWeight.w500,
                c: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
