import 'package:leaderboard/src/leaderboard_entry.dart';

/// Competition ("1224") ranking: sort by score descending, equal scores share a
/// rank, and the next rank skips by the size of the tie group. Four players on
/// 500 / 300 / 300 / 100 rank 1, 2, 2, 4.
///
/// Ties break by player id ascending. That total order is the actual fix for
/// flicker: sorted by score alone, two players on 300 sit in an unspecified
/// relative order and can swap rows on every recomputation. With it the output
/// is a pure function of [scores] — same map in, equal list out — which is what
/// gives the `distinct` on the rankings stream something stable to compare.
///
/// Not exported from `package:leaderboard`. The app never sees this function,
/// only the board it returns.
///
/// ponytail: re-sorts the whole roster per call, O(n log n). Nothing at ~1K
/// players and ~2 events/sec; past a few thousand, index by score bucket and
/// re-place only the player who moved, or recompute only the visible window.
List<LeaderboardEntry> rank(
  Map<String, int> scores,
  Map<String, String> names,
) {
  final sorted = scores.entries.toList()
    ..sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      return byScore != 0 ? byScore : a.key.compareTo(b.key);
    });

  var currentRank = 0;
  int? previousScore;
  final board = <LeaderboardEntry>[];

  for (final (index, entry) in sorted.indexed) {
    if (entry.value != previousScore) {
      currentRank = index + 1;
      previousScore = entry.value;
    }
    // A missing name should degrade to a cosmetic wart, not crash the board.
    // Unreachable while LeaderboardEngine keeps the roster authoritative.
    board.add(
      LeaderboardEntry(
        entry.key,
        names[entry.key] ?? entry.key,
        entry.value,
        currentRank,
      ),
    );
  }

  return board;
}
