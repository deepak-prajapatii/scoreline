import 'package:flutter/material.dart';

/// The two logo colours. Everything else on the board is derived from or tuned
/// against these.
const violet = Color(0xFF7C3AED);

/// Cyan half of the identity gradient, and the scheme's primary.
const cyan = Color(0xFF22D3EE);

/// Rank 1.
const gold = Color(0xFFFBBF24);

/// Rank 2.
const silver = Color(0xFF93C5FD);

/// Rank 3.
const bronze = Color(0xFFFB7185);

/// The "just scored" green: gain chip, glow ring and the LIVE dot.
const gain = Color(0xFF4ADE80);

/// Page background.
const backdrop = Color(0xFF0B0B12);

/// Card background.
const arenaSurface = Color(0xFF14141F);

/// Muted foreground for secondary text and the ranks below third.
const onSurfaceDim = Color(0xFF8A8AA3);

/// Deliberately dark-only, where the rest of the app would follow the system
/// setting.
///
/// Two reasons rather than taste: the violet-to-cyan identity only holds on a
/// dark backdrop, and a board whose whole job is to show motion needs the
/// accent colours to read as light-on-dark. A light variant would mean a second
/// set of accents tuned for contrast on white, which is a real design surface
/// nobody is asking for on a one-screen game.
///
/// There is no `themeMode` and no light [ThemeData]: offering one would be a
/// promise the palette cannot keep.
ThemeData arenaTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: cyan,
      secondary: violet,
      surface: arenaSurface,
      onSurfaceVariant: onSurfaceDim,
    ),
    scaffoldBackgroundColor: backdrop,
  );

  // Only the score styles are overridden, and only for one reason: tabular
  // figures. With proportional digits a right-aligned score column shifts
  // horizontally every time a digit changes width — on a board updating every
  // 500-2000 ms that is constant visible jitter, and it reads as the layout
  // being unstable rather than the score being live.
  //
  // `fontFeatures` rather than a monospace family (which is what the Compose
  // version reaches for): it buys the same fixed-advance digits without
  // changing the typeface, and it is the platform-native way to ask for it.
  const tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall
          ?.merge(tabular)
          .copyWith(fontWeight: FontWeight.bold, fontSize: 20),
      titleMedium: base.textTheme.titleMedium
          ?.merge(tabular)
          .copyWith(fontWeight: FontWeight.bold),
      labelSmall: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    ),
  );
}
