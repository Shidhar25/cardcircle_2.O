import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Shared v1 building blocks (FLUTTER_HANDOFF.md §1.2–§1.3).
///
/// These map 1:1 onto style helpers in the HTML prototype
/// (`primaryBtn`, `avatar`, the `SURF`/`inset 0 0 0 1px BRD` panel pattern,
/// and the pill/segment styles used for filters and tabs) so every screen
/// built on top of them already matches the prototype's spacing and color
/// rules without re-deriving them per screen.

/// `BoxDecoration(color: surface, borderRadius: 8, border: Border.all(color: border))`
/// — the prototype's `inset 0 0 0 1px` panel, used for cards/inputs/list rows.
class OutlinedSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? background;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  const OutlinedSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadii.card,
    this.background,
    this.borderColor,
    this.borderWidth = 1.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: borderWidth,
        ),
      ),
      child: child,
    );

    if (onTap == null) return content;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// Ghost-gold CTA — transparent fill, 1px gold border, gold label, full
/// width, optional trailing icon. Disabled swaps gold for border/textGhost
/// and drops opacity, matching `primaryBtn(enabled)`.
class GoldButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool enabled;
  final double height;
  final bool loading;

  const GoldButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.enabled = true,
    this.height = 52,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = enabled && !loading;
    final Color fg = active ? AppColors.gold : AppColors.textDim;
    final Color border = active ? AppColors.gold : AppColors.border;

    return Opacity(
      opacity: active ? 1.0 : 0.55,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.card),
            onTap: active ? onTap : null,
            splashColor: AppColors.gold.withValues(alpha: 0.12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: border, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: 9),
                  ] else ...[
                    Text(
                      label,
                      style: AppText.sans(
                        13.5,
                        weight: FontWeight.w500,
                        color: fg,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 9),
                      Icon(icon, size: 15, color: fg),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient accent panel — `goldSurface → background` at ~140deg with a
/// gold border at 40% alpha; [teal] swaps in the teal palette.
enum AccentKind { gold, teal }

class AccentPanel extends StatelessWidget {
  final Widget child;
  final AccentKind kind;
  final EdgeInsetsGeometry padding;
  final double radius;

  const AccentPanel({
    super.key,
    required this.child,
    this.kind = AccentKind.gold,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadii.card,
  });

  @override
  Widget build(BuildContext context) {
    final Color surfaceColor = kind == AccentKind.gold
        ? AppColors.goldSurface
        : AppColors.tealSurface;
    final Color accentColor = kind == AccentKind.gold
        ? AppColors.gold
        : AppColors.teal;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          begin: const Alignment(-0.64, -0.77), // ~140deg
          end: const Alignment(0.64, 0.77),
          colors: [surfaceColor, AppColors.background],
        ),
      ),
      child: child,
    );
  }
}

/// Uppercase mono label — every stat, tab, and category tag in the
/// prototype runs through JetBrains Mono at small sizes with wide tracking.
class MonoLabel extends StatelessWidget {
  final String text;
  final double size;
  final double letterSpacing;
  final FontWeight weight;
  final Color? color;
  final bool uppercase;
  final int? maxLines;
  final TextOverflow overflow;

  const MonoLabel(
    this.text, {
    super.key,
    this.size = 10,
    this.letterSpacing = 1.2,
    this.weight = FontWeight.w400,
    this.color,
    this.uppercase = true,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      uppercase ? text.toUpperCase() : text,
      maxLines: maxLines,
      overflow: overflow,
      style: AppText.mono(
        size,
        ls: letterSpacing,
        w: weight,
        c: color ?? AppColors.textDim,
      ),
    );
  }
}

/// The 150deg card-face gradient used for catalog thumbnails and the home
/// card stack, e.g. `linear-gradient(150deg,#3f424d,#161826 68%)`.
class CardFace {
  final Color top;
  final Color bottom;
  final double bottomStop;

  const CardFace(this.top, this.bottom, {this.bottomStop = 0.68});

  LinearGradient get gradient => LinearGradient(
    begin: const Alignment(-0.64, -1.0), // ~150deg
    end: const Alignment(0.64, 1.0),
    colors: [top, bottom],
    stops: [0.0, bottomStop],
  );

  static const millennia = CardFace(Color(0xFF3F424D), Color(0xFF161826));
  static const ace = CardFace(
    Color(0xFF1F3B39),
    Color(0xFF161826),
    bottomStop: 0.70,
  );
  static const amazonPay = CardFace(
    Color(0xFF3B2F16),
    Color(0xFF161826),
    bottomStop: 0.70,
  );
  static const cashback = CardFace(
    Color(0xFF2B2741),
    Color(0xFF161826),
    bottomStop: 0.70,
  );
  static const magnus = CardFace(
    Color(0xFF292B31),
    Color(0xFF161826),
    bottomStop: 0.66,
  );
  static const regaliaGold = CardFace(
    Color(0xFF423A6A),
    Color(0xFF161826),
    bottomStop: 0.70,
  );
  static const infinia = CardFace(
    Color(0xFF3F424D),
    Color(0xFF1B1D29),
    bottomStop: 0.70,
  );
  static const simplyClick = CardFace(
    Color(0xFF1F3B39),
    Color(0xFF1B1D29),
    bottomStop: 0.70,
  );
}

/// Small 52x34 card-face thumbnail with the gold-tinted magstripe/dots
/// treatment used in the Add Cards list and recommendation chips.
class CardFaceThumb extends StatelessWidget {
  final CardFace face;
  final double width;
  final double height;

  const CardFaceThumb({
    super.key,
    required this.face,
    this.width = 52,
    this.height = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.chip),
        gradient: face.gradient,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.34)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 7,
            top: 7,
            child: Container(
              width: 12,
              height: 9,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  begin: Alignment(-0.64, -0.84),
                  end: Alignment(0.64, 0.84),
                  colors: [AppColors.goldLight, AppColors.goldDark],
                ),
              ),
            ),
          ),
          Positioned(
            left: 7,
            bottom: 6,
            child: Text(
              '••••',
              style: AppText.mono(
                5.5,
                ls: 0.8,
                c: AppColors.text.withValues(alpha: 0.66),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circle avatar with the prototype's four gradient hues.
enum AvatarHue { gold, teal, violet, steel }

class AvatarBubble extends StatelessWidget {
  final String initials;
  final double size;
  final AvatarHue hue;

  const AvatarBubble({
    super.key,
    required this.initials,
    this.size = 36,
    this.hue = AvatarHue.gold,
  });

  static const Map<AvatarHue, List<Color>> _gradients = {
    AvatarHue.gold: [Color(0xFFF0D79F), Color(0xFF8A6B24)],
    AvatarHue.teal: [Color(0xFF5FB3A9), Color(0xFF1F3B39)],
    AvatarHue.violet: [Color(0xFFB5ABFC), Color(0xFF423A6A)],
    AvatarHue.steel: [Color(0xFFB2B6CA), Color(0xFF3F424D)],
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: const Alignment(-0.64, -1.0),
          end: const Alignment(0.64, 1.0),
          colors: _gradients[hue]!,
        ),
      ),
      child: Text(
        initials,
        style: AppText.mono(
          size * 0.34,
          ls: 0,
          w: FontWeight.w700,
          c: AppColors.background,
        ),
      ),
    );
  }
}

/// Pill filter chip — `flex:none;padding:7px 14px;border-radius:20px`,
/// selected = gold@12% fill + gold border + gold text, else transparent +
/// border + textDim. Used for category/topic filter rows.
class FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            color: selected
                ? AppColors.gold.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppText.sans(
              12,
              color: selected ? AppColors.gold : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Two/three-way segmented switcher — `flex:1;height:38px;border-radius:6px`
/// mono label, selected = gold@14% fill + gold inset border + gold text.
class SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double fontSize;

  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final bool on = i == selectedIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    color: on
                        ? AppColors.gold.withValues(alpha: 0.14)
                        : Colors.transparent,
                    border: on
                        ? Border.all(
                            color: AppColors.gold.withValues(alpha: 0.45),
                          )
                        : null,
                  ),
                  child: MonoLabel(
                    labels[i],
                    size: fontSize,
                    letterSpacing: 1.3,
                    color: on ? AppColors.gold : AppColors.textFaint,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Small icon-tile — `width/height:34-38px;border-radius:8px;background:elevated`
/// used for back buttons, notification icon wraps, etc.
class IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? background;
  final VoidCallback? onTap;

  const IconTile({
    super.key,
    required this.icon,
    this.size = 38,
    this.iconSize = 17,
    this.color,
    this.background,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, size: iconSize, color: color ?? AppColors.text),
    );

    if (onTap == null) return tile;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(onTap: onTap, child: tile),
    );
  }
}

/// Rupee formatting helpers matching the prototype's `inr`/`short` helpers.
class Money {
  static String inr(num n) {
    final rounded = n.round();
    final s = rounded.toString();
    final buf = StringBuffer();
    final isNeg = s.startsWith('-');
    final digits = isNeg ? s.substring(1) : s;
    if (digits.length <= 3) {
      buf.write(digits);
    } else {
      final head = digits.substring(0, digits.length - 3);
      final tail = digits.substring(digits.length - 3);
      final groups = <String>[];
      var rest = head;
      while (rest.length > 2) {
        groups.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) groups.insert(0, rest);
      buf.write('${groups.join(',')},$tail');
    }
    return '${isNeg ? '-' : ''}₹${buf.toString()}';
  }

  static String short(num n) {
    if (n >= 100000) {
      final v = n / 100000;
      final s = v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
      return '₹${s}L';
    }
    final v = n / 1000;
    final s = v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return '₹${s}K';
  }
}

/// The registration progress bar — one gold segment per completed step.
///
/// Registration is a fixed three-step flow (profile, categories, cards), and
/// each screen previously drew its own bar with its own segment count, which
/// is how "Step 1 of 2" ended up next to "Step 2 of 3". Owning the total in
/// one place makes that class of drift impossible.
class StepProgressBar extends StatelessWidget {
  /// 1-based index of the step currently on screen.
  final int currentStep;

  /// Total steps in the registration flow.
  static const int totalSteps = 3;

  const StepProgressBar({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final bool done = i < currentStep;
        return Expanded(
          child: Container(
            height: 2,
            margin: EdgeInsets.only(
              right: i == totalSteps - 1 ? 0 : AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: done ? AppColors.gold : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
