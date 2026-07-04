import 'package:flutter/material.dart';

/// Semantic status colors shared by [AuctionStatusPill], [BidControlBar], and
/// the Auction Results summary — one source of truth instead of each screen
/// hardcoding its own green/orange/red.
const kStatusSold = Color(0xFF2E7D32);
const kStatusWarning = Color(0xFFED6C02);
const kStatusDanger = Color(0xFFD32F2F);

/// The app's single shared design system. Keeps the existing deepPurple
/// brand seed; layers on Material 3 "flat/tonal" component theming
/// (cards, inputs, buttons, app bars) so every screen gets consistent
/// sectioning and hierarchy without repeating styling at each call site.
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
  final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);

  final radius12 = BorderRadius.circular(12);

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: base.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius12, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radius12, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: BorderSide(color: colorScheme.outline),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    dividerTheme: DividerThemeData(
      space: 1,
      thickness: 1,
      color: colorScheme.outlineVariant,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: radius12),
    ),
  );
}
