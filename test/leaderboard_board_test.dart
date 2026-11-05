import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaderboard/leaderboard.dart';
import 'package:scoreline/theme/arena_theme.dart';
import 'package:scoreline/ui/leaderboard_screen.dart';

/// Deliberately includes a two-way tie on rank 2 and the rank-4 skip that
/// follows it, because competition ranking is the thing most likely to be
/// broken by a layout change and the least likely to show up in a screenshot
/// taken at a random moment.
const _sample = [
  LeaderboardEntry('p5', 'Alan', 733, 1),
  LeaderboardEntry('p4', 'Barbara', 648, 2),
  LeaderboardEntry('p8', 'Dennis', 648, 2),
  LeaderboardEntry('p1', 'Ada', 602, 4),
  LeaderboardEntry('p6', 'Katherine', 585, 5),
  LeaderboardEntry('p3', 'Linus', 558, 6),
  LeaderboardEntry('p7', 'Margaret', 0, 7),
  LeaderboardEntry('p2', 'Grace', 0, 7),
];

Widget _wrap(List<LeaderboardEntry> entries) => MaterialApp(
  theme: arenaTheme(),
  home: LeaderboardBoard(entries: entries),
);

void main() {
  testWidgets('renders one row per player', (tester) async {
    await tester.pumpWidget(_wrap(_sample));

    for (final entry in _sample) {
      expect(find.text(entry.name), findsOneWidget);
    }
  });

  testWidgets('the header derives its counts from the board, not decoration', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_sample));

    // 733 + 648 + 648 + 602 + 585 + 558 = 3774.
    expect(find.text('8 players · 3774 pts in play'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
  });

  testWidgets('a tie shares a rank and the next rank skips it', (tester) async {
    await tester.pumpWidget(_wrap(_sample));

    // Two rows show "2", and no row shows "3".
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('3'), findsNothing);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('a row keeps its identity when ranks swap', (tester) async {
    await tester.pumpWidget(_wrap(_sample));

    // Grace overtakes Margaret: same players, different order.
    const swapped = [
      LeaderboardEntry('p5', 'Alan', 733, 1),
      LeaderboardEntry('p4', 'Barbara', 648, 2),
      LeaderboardEntry('p8', 'Dennis', 648, 2),
      LeaderboardEntry('p1', 'Ada', 602, 4),
      LeaderboardEntry('p6', 'Katherine', 585, 5),
      LeaderboardEntry('p3', 'Linus', 558, 6),
      LeaderboardEntry('p2', 'Grace', 40, 7),
      LeaderboardEntry('p7', 'Margaret', 0, 8),
    ];
    await tester.pumpWidget(_wrap(swapped));
    await tester.pump(const Duration(milliseconds: 400));

    // The gain chip is attached to Grace, the player who actually scored — that
    // is what the per-player key buys. Without it the chip would land on
    // whichever row happened to occupy the slot.
    expect(find.text('+40'), findsOneWidget);
  });

  testWidgets('an empty board renders the header and nothing else', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const []));

    expect(find.text('0 players · 0 pts in play'), findsOneWidget);
    expect(find.text('SCORELINE'), findsOneWidget);
  });
}
