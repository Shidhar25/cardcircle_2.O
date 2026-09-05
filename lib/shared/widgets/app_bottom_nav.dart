import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../core/theme/app_theme.dart';

/// v1 bottom nav — Home · Benefits · Circle · Profile (FLUTTER_HANDOFF.md
/// §2 "Navigation"). Matches CardCircle.html's `nav` block: a 64px blurred
/// bar (`rgba(35,37,50,.94)` + `backdrop-filter: blur(14px)`), inset
/// 1px border, mono 8px labels, and a sliding gold underline dot per tab.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _tabs = [
    (
      icon: PhosphorIconsRegular.house,
      iconFilled: PhosphorIconsFill.house,
      label: 'HOME',
    ),
    (
      icon: PhosphorIconsRegular.compass,
      iconFilled: PhosphorIconsFill.compass,
      label: 'BENEFITS',
    ),
    (
      icon: PhosphorIconsRegular.usersThree,
      iconFilled: PhosphorIconsFill.usersThree,
      label: 'CIRCLE',
    ),
    (
      icon: PhosphorIconsRegular.user,
      iconFilled: PhosphorIconsFill.user,
      label: 'PROFILE',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final bool on = i == currentIndex;
                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            on ? tab.iconFilled : tab.icon,
                            size: 21,
                            color: on ? AppColors.gold : AppColors.textDim,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            tab.label,
                            style: AppText.mono(
                              8,
                              ls: 1.2,
                              c: on ? AppColors.gold : AppColors.textDim,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            width: on ? 14 : 0,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
