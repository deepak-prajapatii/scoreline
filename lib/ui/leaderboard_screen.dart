import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leaderboard/leaderboard.dart';
import 'package:scoreline/di/app_container.dart';
import 'package:scoreline/theme/arena_theme.dart';
import 'package:scoreline/ui/leaderboard_header.dart';
import 'package:scoreline/ui/leaderboard_row.dart';

const _rowGap = 8.0;
const _rowStep = rowHeight + _rowGap;

/// Stateful variant: watches [rankingsProvider] and renders it.
///
/// The Compose original is one overloaded function; Dart has no overloads, so
/// the pair is two widgets. The split is the same and exists for the same
/// reason — everything below this line is testable with a plain list and no
/// isolate, no provider and no clock.
class LeaderboardScreen extends ConsumerWidget {
  /// Creates the connected screen.
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No error branch and no spinner: the stream cannot fail (the engine is
    // local and validated at construction) and its first board arrives in the
    // same frame the isolate finishes spawning. An empty board renders as the
    // header alone, the correct thing to show for that one frame.
    final entries = ref.watch(rankingsProvider).value ?? const [];
    return LeaderboardBoard(entries: entries);
  }
}

/// Stateless variant: previewable, and testable without a provider or a match.
class LeaderboardBoard extends StatefulWidget {
  /// Creates the board over an already-ranked [entries] list.
  const LeaderboardBoard({required this.entries, super.key});

  /// The board, already sorted by score descending.
  final List<LeaderboardEntry> entries;

  @override
  State<LeaderboardBoard> createState() => _LeaderboardBoardState();
}

class _LeaderboardBoardState extends State<LeaderboardBoard> {
  // Handed to every row and read only inside their painters, so the leader
  // scoring a point repaints the bars without rebuilding a single row.
  final ValueNotifier<int> _topScore = ValueNotifier(0);

  @override
  void dispose() {
    _topScore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    // The list is already sorted by score descending, so the leader is simply
    // the first entry.
    _topScore.value = entries.isEmpty ? 0 : entries.first.score;
    final totalPoints = entries.fold<int>(0, (sum, entry) => sum + entry.score);

    return Scaffold(
      backgroundColor: backdrop,
      body: SafeArea(
        // All four edges, not just top and bottom. In landscape the navigation
        // bar sits on one side, so dropping the horizontal insets runs the
        // score column and the LIVE badge underneath it. SafeArea is
        // direction-aware, which is what handles RTL.
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              LeaderboardHeader(
                playerCount: entries.length,
                totalPoints: totalPoints,
              ),
              const SizedBox(height: 12),
              // Rows are positioned rather than laid out in order, and each one
              // is keyed by player. That key is load-bearing twice over: it is
              // what makes two players swapping ranks read as *one row moving*
              // — AnimatedPositioned slides it — and it is what keeps each
              // row's remembered previous score attached to its own player, so
              // a swap does not flash two rows for a change neither of them
              // had.
              //
              // ponytail: a Stack lays every row out at once, so this does not
              // virtualise. Correct for a roster that fits on screen; past a
              // few hundred players, move to a keyed ListView and drive the
              // slide from an explicit rank-change animation.
              SizedBox(
                height: entries.isEmpty
                    ? 0
                    : entries.length * _rowStep - _rowGap,
                child: Stack(
                  children: [
                    for (final (index, entry) in entries.indexed)
                      AnimatedPositioned(
                        key: ValueKey(entry.playerId),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        top: index * _rowStep,
                        left: 14,
                        right: 14,
                        height: rowHeight,
                        child: LeaderboardRow(
                          entry: entry,
                          topScore: _topScore,
                          tiedWithAbove:
                              index > 0 &&
                              entries[index - 1].rank == entry.rank,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
