import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const blue = Color(0xFF1764ED);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: blue,
          brightness: brightness,
          surface: brightness == Brightness.dark
              ? const Color(0xFF131E30)
              : const Color(0xFFF7F9FD),
        ).copyWith(
          primary: isDark ? const Color(0xFF9FC2FF) : blue,
          onPrimary: isDark ? const Color(0xFF002558) : Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF19365C)
              : const Color(0xFFE4EEFF),
          onPrimaryContainer: isDark
              ? const Color(0xFFD4E5FF)
              : const Color(0xFF143673),
          surfaceContainerLowest: isDark
              ? const Color(0xFF0B1220)
              : Colors.white,
          surfaceContainerLow: isDark
              ? const Color(0xFF101C2E)
              : const Color(0xFFEFF5FF),
          surfaceContainer: isDark
              ? const Color(0xFF162338)
              : const Color(0xFFF0F4FA),
          surfaceContainerHigh: isDark
              ? const Color(0xFF1C2C43)
              : const Color(0xFFEAF0F8),
          surfaceContainerHighest: isDark
              ? const Color(0xFF23344D)
              : const Color(0xFFE1EAF6),
          outlineVariant: isDark
              ? const Color(0xFF293950)
              : const Color(0xFFDCE5F1),
          onSurface: isDark ? const Color(0xFFEDF3FF) : const Color(0xFF14213A),
          onSurfaceVariant: isDark
              ? const Color(0xFFAFBDD3)
              : const Color(0xFF52627B),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: ThemeData(brightness: brightness).textTheme.copyWith(
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: scheme.onSurface,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: scheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.4,
          color: scheme.onSurface,
        ),
      ),
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0B1220)
          : const Color(0xFFF7F9FD),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? const Color(0xFF0B1220)
            : const Color(0xFFF7F9FD),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF131E30) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? const Color(0xFF293950) : const Color(0xFFDCE5F1),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.45),
        selectedColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 400),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF0D1727) : const Color(0xFFF7F9FD),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: blue, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF101827)
            : const Color(0xFFFFFFFF),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF293950) : const Color(0xFFDCE5F1),
        thickness: 1,
      ),
    );
  }
}
