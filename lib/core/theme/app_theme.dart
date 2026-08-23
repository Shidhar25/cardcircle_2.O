import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CardCircle v1 palette — gold on Nocturne charcoal.
/// See FLUTTER_HANDOFF.md §1 for the source table.
///
/// Existing field names (background, card, primary, mutedForeground, ...)
/// are kept so every screen already using [AppColors] rethemes for free.
/// The canonical spec names (surface, textMuted, goldLight, ...) are added
/// as aliases for new/updated screens to use going forward.
class AppColors {
  // --- Canonical v1 tokens (§1) ---
  static const Color background = Color(0xFF161826);
  static const Color surface = Color(0xFF232532);
  static const Color elevated = Color(0xFF292B31);
  static const Color border = Color(0xFF3F424D);

  static const Color gold = Color(0xFFD8AE4E);
  static const Color goldLight = Color(0xFFF0D79F);
  static const Color goldDark = Color(0xFF8A6B24);

  static const Color teal = Color(0xFF5FB3A9);
  static const Color tealSurface = Color(0xFF1F3B39);
  static const Color goldSurface = Color(0xFF2A2415);

  static const Color text = Color(0xFFE9E9ED);
  static const Color textMuted = Color(0xFFCFD3E5);
  static const Color textDim = Color(0xFF9397AB);
  static const Color textFaint = Color(0xFF75798C);
  static const Color textGhost = Color(0xFF595D6C);

  static const Color destructive = Color(0xFFFF4757);
  static const Color destructiveForeground = Color(0xFFFFFFFF);

  // --- Legacy aliases kept so existing screens retheme without edits ---
  static const Color foreground = text;
  static const Color card = surface;
  static const Color cardForeground = text;

  static const Color primary = gold;
  static const Color primaryForeground = background;
  static const Color secondary = teal;
  static const Color secondaryForeground = background;

  static const Color headerText = goldLight;
  static const Color darkText = background;
  static const Color tint = gold;

  static const Color muted = surface;
  static const Color mutedForeground = textDim;

  static const Color accent = teal;
  static const Color accentForeground = background;

  static const Color input = surface;

  static const Color cyan = teal;
  static const Color green = teal;
  static const Color purple = goldLight;

  static const double radius = 8.0;

  static List<BoxShadow> get limeGlow => [
        BoxShadow(
          color: gold.withValues(alpha: 0.35),
          blurRadius: 16,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> get cyanGlow => limeGlow;
  static List<BoxShadow> get greenGlow => limeGlow;
}

/// Radius scale (§1). Chips/card faces use [chip], cards/buttons/inputs use
/// [card], pills use [pill], avatars use [avatar] (50%, apply via
/// BoxShape.circle or a computed radius).
class AppRadii {
  static const double chip = 6.0;
  static const double card = 8.0;
  static const double pill = 20.0;
}

/// Spacing scale (§1), rounded from the prototype's fractional values.
class AppSpacing {
  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double mdLg = 14.0;
  static const double lg = 16.0;
  static const double xl = 22.0;
  static const double xxl = 26.0;
  static const double xxxl = 30.0;
}

/// Type helpers (§1 "Type"). Inter for UI text, JetBrains Mono for every
/// uppercase label / number / currency / stat.
class AppText {
  static TextStyle sans(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.text,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle mono(
    double size, {
    double ls = 1.4,
    FontWeight w = FontWeight.w400,
    Color? c,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        letterSpacing: ls,
        fontWeight: w,
        color: c ?? AppColors.text,
      );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.gold,
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.teal,
        surface: AppColors.surface,
        error: AppColors.destructive,
        onPrimary: AppColors.background,
        onSecondary: AppColors.background,
        onSurface: AppColors.text,
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: TextTheme(
        // Titles: Inter, medium weight per spec (no dedicated display face).
        displayLarge: AppText.sans(27, weight: FontWeight.w500, color: AppColors.text, letterSpacing: -0.5),
        displayMedium: AppText.sans(25, weight: FontWeight.w500, color: AppColors.text, letterSpacing: -0.3),
        headlineLarge: AppText.sans(21, weight: FontWeight.w500, color: AppColors.text),
        headlineMedium: AppText.sans(17, weight: FontWeight.w500, color: AppColors.text),

        // Tabs & metadata: JetBrains Mono, uppercase labels/stats.
        labelLarge: AppText.mono(13, w: FontWeight.w700, c: AppColors.gold),
        labelMedium: AppText.mono(12, w: FontWeight.w400, c: AppColors.textDim, ls: 1.2),
        labelSmall: AppText.mono(11, w: FontWeight.w400, c: AppColors.textFaint, ls: 1.2),

        // Subheadings.
        titleLarge: AppText.sans(15.5, weight: FontWeight.w500, color: AppColors.text, letterSpacing: 0.2),
        titleMedium: AppText.sans(13.5, weight: FontWeight.w400, color: AppColors.textMuted),

        // Body text.
        bodyLarge: AppText.sans(14, weight: FontWeight.w400, color: AppColors.text),
        bodyMedium: AppText.sans(13, weight: FontWeight.w400, color: AppColors.textMuted),
        bodySmall: AppText.sans(12, weight: FontWeight.w400, color: AppColors.textDim),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.sans(17, weight: FontWeight.w500, color: AppColors.text),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.elevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
