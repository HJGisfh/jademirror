import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const Color ink900 = Color(0xFF142521);
  static const Color ink700 = Color(0xFF22433d);
  static const Color ink600 = Color(0xFF2f5750);
  static const Color ink500 = Color(0xFF40645d);
  static const Color ink400 = Color(0xFF5f7b74);

  static const Color jade300 = Color(0xFFc7ddcf);
  static const Color jade200 = Color(0xFFdceadf);
  static const Color jade100 = Color(0xFFedf5ee);

  static const Color paper = Color(0xFFf8f3e8);
  static const Color paperDeep = Color(0xFFefe6d8);

  static const Color amber = Color(0xFF95612d);
  static const Color danger = Color(0xFFa44e3f);

  static const Color cardBorder = Color(0x1F254841);
  static const Color cardBg = Color(0xC7FFFFFF);

  static const Color primaryGradientStart = Color(0xFF2f5d52);
  static const Color primaryGradientEnd = Color(0xFF4d7b6f);

  static const Color secondaryBg = Color(0xE5DCEADF);
  static const Color secondaryBorder = Color(0x333A5759);

  static const Color warnGradientStart = Color(0xFF8f483a);
  static const Color warnGradientEnd = Color(0xFFb15f4d);

  static const Color focusRing = Color(0x3D528572);

  static const Color petIdle = Color(0xFFa8d5c4);
  static const Color petListening = Color(0xFF7ec8a8);
  static const Color petThinking = Color(0xFFd4c47a);
  static const Color petSpeaking = Color(0xFF8dd4b8);
  static const Color petCheek = Color(0xFFf0b8a8);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppRadius {
  AppRadius._();

  static const double lg = 24.0;
  static const double md = 16.0;
  static const double sm = 12.0;
  static const double pill = 999.0;
}

class AppDurations {
  AppDurations._();

  static const Duration riseIn = Duration(milliseconds: 350);
  static const Duration quick = Duration(milliseconds: 200);
  static const Duration spin = Duration(milliseconds: 800);
  static const Duration breathe = Duration(milliseconds: 2500);
  static const Duration bob = Duration(milliseconds: 3000);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final baseTextTheme = GoogleFonts.notoSerifScTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.ink900, letterSpacing: 1),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.ink900, letterSpacing: 1),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.ink900),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.ink900, letterSpacing: 0.5),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink900),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink900),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink700),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink700),
        bodyLarge: TextStyle(fontSize: 15, color: AppColors.ink700, height: 1.7),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.ink700, height: 1.6),
        bodySmall: TextStyle(fontSize: 13, color: AppColors.ink500, height: 1.5),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.ink500),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: baseTextTheme,
      fontFamily: GoogleFonts.notoSansSc().fontFamily,
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryGradientStart,
        onPrimary: const Color(0xFFf6f7f5),
        secondary: AppColors.jade200,
        onSecondary: AppColors.ink700,
        surface: AppColors.paper,
        onSurface: AppColors.ink900,
        error: AppColors.danger,
        outline: AppColors.ink400,
        outlineVariant: AppColors.cardBorder,
      ),
      scaffoldBackgroundColor: AppColors.paper,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        color: AppColors.cardBg,
        shadowColor: const Color(0x1A203934),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18.4, vertical: 9.92),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
          textStyle: baseTextTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper.withValues(alpha: 0.9),
        foregroundColor: AppColors.ink900,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: baseTextTheme.titleLarge,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.cardBorder,
        thickness: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
