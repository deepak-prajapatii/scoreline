import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoreline/theme/arena_theme.dart';
import 'package:scoreline/ui/leaderboard_screen.dart';

/// Entry point. Wires the arena theme and the leaderboard screen — nothing else
/// lives here by design, which is what the Android app's 20-line `MainActivity`
/// is also saying.
void main() {
  // Draw behind the status and navigation bars, with light icons over the dark
  // backdrop. The counterpart of `enableEdgeToEdge()`; `SafeArea` in the screen
  // supplies the insets it exposes.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const ProviderScope(child: ScorelineApp()));
}

/// The app shell. One screen, no router: `go_router` would be a dependency with
/// nothing to route.
class ScorelineApp extends StatelessWidget {
  /// Creates the app.
  const ScorelineApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Scoreline',
    debugShowCheckedModeBanner: false,
    theme: arenaTheme(),
    home: const LeaderboardScreen(),
  );
}
