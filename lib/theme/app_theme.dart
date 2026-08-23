import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/theme/app_colors.dart';

class AppTheme {
  AppTheme._();

  static const _pageTransitions = PageTransitionsTheme(builders: {
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
  });

  static ThemeData get lightTheme {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      error: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.divider,
      outlineVariant: AppColors.divider,
      surfaceContainerLow: Color(0xFFF9FAF7),
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: Color(0xFFEAEEE9),
    );
    return _build(
      brightness: Brightness.light,
      scheme: scheme,
      background: AppColors.background,
      surface: AppColors.surface,
      fieldFill: AppColors.glassSurface,
      cardBorder: AppColors.divider,
      modalBarrier: const Color(0x52000000),
    );
  }

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
      onPrimary: const Color(0xFF07130F),
      primaryContainer: const Color(0xFF29483D),
      onPrimaryContainer: const Color(0xFFD9F9EC),
      secondary: const Color(0xFFF0A365),
      surfaceContainerLow: const Color(0xFF171B19),
      surfaceContainer: container,
      surfaceContainerHigh: const Color(0xFF272D2A),
      surfaceContainerHighest: const Color(0xFF2D3430),
      outline: const Color(0xFF3A423E),
      outlineVariant: const Color(0xFF303733),
      onSurface: text,
      onSurfaceVariant: muted,
    );
    return _build(
      brightness: Brightness.dark,
      scheme: scheme,
      background: background,
      surface: surface,
      fieldFill: container,
      cardBorder: const Color(0xFF303733),
      modalBarrier: const Color(0x99000000),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color background,
    required Color surface,
    required Color fieldFill,
    required Color cardBorder,
    required Color modalBarrier,
  }) {
    final dark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      cardColor: surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: _pageTransitions,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, scheme),
      appBarTheme: AppBarTheme(
        backgroundColor: background.withValues(alpha: .94),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -.25,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: dark ? 0 : 1,
        shadowColor: AppColors.primaryDark.withValues(alpha: .08),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cardBorder, width: .8),
        ),
      ),
      inputDecorationTheme: _inputTheme(scheme, fieldFill),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: dark ? 0 : 1,
          shadowColor: AppColors.primaryDark.withValues(alpha: .22),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: shape,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: shape,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          backgroundColor: fieldFill.withValues(alpha: dark ? .74 : .72),
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: scheme.outlineVariant),
          shape: shape,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          highlightColor: scheme.primary.withValues(alpha: .08),
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: dark ? 1 : 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fieldFill.withValues(alpha: dark ? .9 : .78),
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle:
            TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(
            color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surfaceContainerHigh),
        thumbColor:
            WidgetStatePropertyAll(dark ? scheme.onSurface : Colors.white),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onPrimaryContainer,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        indicator: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(13),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(13),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerColor: cardBorder,
      dividerTheme: DividerThemeData(color: cardBorder, thickness: .8),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            dark ? scheme.surfaceContainerHigh : AppColors.surfaceDark,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: modalBarrier,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: dark ? 2 : 8,
        shadowColor: AppColors.primaryDark.withValues(alpha: .16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -.35,
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    return base
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          displayLarge: TextStyle(
              fontSize: 36,
              height: 1.08,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              letterSpacing: -1.2),
          headlineLarge: TextStyle(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              letterSpacing: -.7),
          headlineMedium: TextStyle(
              fontSize: 21,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              letterSpacing: -.35),
          titleLarge: TextStyle(
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              letterSpacing: -.2),
          titleMedium: TextStyle(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface),
          bodyLarge:
              TextStyle(fontSize: 16, height: 1.5, color: scheme.onSurface),
          bodyMedium: TextStyle(
              fontSize: 14, height: 1.45, color: scheme.onSurfaceVariant),
          bodySmall: TextStyle(
              fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant),
          labelLarge: TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface),
          labelMedium: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant),
        );
  }

  static InputDecorationTheme _inputTheme(ColorScheme scheme, Color fill) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      floatingLabelStyle:
          TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
      hintStyle:
          TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: .86)),
      helperStyle: TextStyle(color: scheme.onSurfaceVariant),
      errorStyle: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      border: border(scheme.outlineVariant),
      enabledBorder: border(scheme.outlineVariant),
      focusedBorder: border(scheme.primary, 1.5),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.5),
    );
  }
}
