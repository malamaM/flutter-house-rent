import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    const background = Color(0xFF101311);
    const surface = Color(0xFF191D1B);
    const container = Color(0xFF222725);
    const text = Color(0xFFF3F5F4);
    const muted = Color(0xFFA7B0AC);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      surface: surface,
    ).copyWith(
      primary: const Color(0xFF78D6B5),
      secondary: const Color(0xFFF0A365),
      surfaceContainer: container,
      surfaceContainerHighest: const Color(0xFF2A302D),
      outline: const Color(0xFF3A423E),
      onSurface: text,
      onSurfaceVariant: muted,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      primaryColor: scheme.primary,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      cardColor: surface,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
          .apply(bodyColor: text, displayColor: text)
          .copyWith(
              bodyMedium:
                  GoogleFonts.inter(color: muted, fontSize: 14, height: 1.45)),
      appBarTheme: AppBarTheme(
          backgroundColor: background.withValues(alpha: .94),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: GoogleFonts.inter(
              color: text, fontSize: 20, fontWeight: FontWeight.w700),
          iconTheme: const IconThemeData(color: text)),
      cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF303633)))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: container,
          labelStyle: const TextStyle(color: muted),
          hintStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF39413D))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF39413D))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: scheme.primary, width: 1.5))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: const Color(0xFF07130F),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: scheme.primary,
              backgroundColor: container,
              side: const BorderSide(color: Color(0xFF39413D)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)))),
      dividerColor: const Color(0xFF303633),
      chipTheme: ChipThemeData(
        backgroundColor: container,
        selectedColor: const Color(0xFF29483D),
        side: const BorderSide(color: Color(0xFF39413D)),
        labelStyle: const TextStyle(color: text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.primary
                : const Color(0xFF39413D)),
        thumbColor: const WidgetStatePropertyAll(Color(0xFFF3F5F4)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          modalBarrierColor: Color(0x99000000),
          showDragHandle: true),
      dialogTheme: DialogThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      snackBarTheme: SnackBarThemeData(
          backgroundColor: container,
          contentTextStyle: GoogleFonts.inter(color: text),
          behavior: SnackBarBehavior.floating),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      brightness: Brightness.light,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      }),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 36,
          height: 1.08,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -1.2,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.7,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.35,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
        labelLarge:
            GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.divider),
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.divider),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.error),
          borderRadius: BorderRadius.circular(16),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          shadowColor: AppColors.primaryDark.withValues(alpha: .24),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.white.withValues(alpha: .72),
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          highlightColor: AppColors.primary.withValues(alpha: .08),
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: .78),
        selectedColor: AppColors.primaryLight.withValues(alpha: .9),
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.surfaceContainer),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.glassSurface,
        elevation: 1,
        shadowColor: AppColors.primaryDark.withValues(alpha: .08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background.withValues(alpha: .92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.divider, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.glassSurface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0x52000000),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.glassSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.primaryDark.withValues(alpha: .16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.error,
        surface: AppColors.surface,
      ),
    );
  }
}
