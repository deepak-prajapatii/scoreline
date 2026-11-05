import 'dart:async';

import 'package:leaderboard/src/leaderboard_entry.dart';
import 'package:leaderboard/src/ranking.dart';
import 'package:leaderboard/src/score_delta.dart';

/// Accumulates [ScoreDelta]s into running totals and exposes the ranked board.
///
/// Owns no long-lived subscription of its own: [consume] returns a `Future`
/// that completes when the delta stream does, so the lifecycle decision — does
/// the board keep advancing while backgrounded? — belongs to the caller,
/// exactly as the Kotlin `suspend fun consume` leaves it to the caller's scope.
class LeaderboardEngine {
  /// Creates a board over a fixed [roster] of `(id, name)` pairs.
  ///
  /// Throws [ArgumentError] if two players share an id: silently collapsing
  /// them would leave a player who can never score.
  LeaderboardEngine(List<(String id, String name)> roster)
      : _names = {for (final (id, name) in roster) id: name},
        _scores = {for (final (id, _) in roster) id: 0} {
    if (_names.length != roster.length) {
      throw ArgumentError('roster contains duplicate player ids');
    }
  }

  final Map<String, String> _names;

  // State lives here, not in the stream. A `scan`-style fold over the delta
  // stream would be shorter and wrong: the accumulator resets every time the
  // last listener goes away and a new one arrives — every rotation, every
  // return from background. Keeping it out here is what makes resubscription
  // free, and what lets the UI layer drop its subscription without consequence.
  final Map<String, int> _scores;

  final StreamController<Map<String, int>> _changes =
      StreamController<Map<String, int>>.broadcast();

  /// The ranked board, re-derived on every change that actually moves it.
  ///
  /// Emits the current board immediately on listen, so a returning subscriber
  /// costs exactly one `rank()` call rather than a replay of every event it
  /// missed. `distinct` is the guard for a changed score map that ranks
  /// identically: points can change without the board changing, and when that
  /// happens the screen is never told and so never redraws.
  ///
  /// `Stream.multi` rather than a plain broadcast stream: every listener gets
  /// its own subscription, and the current board is emitted synchronously on
  /// listen with no window in which a delta can slip past unseen.
  Stream<List<LeaderboardEntry>> get rankings =>
      Stream<List<LeaderboardEntry>>.multi((controller) {
        final subscription = _changes.stream
            .listen((scores) => controller.add(rank(scores, _names)));
        controller
          ..add(rank(_scores, _names))
          ..onCancel = subscription.cancel;
      }).distinct(_sameBoard);

  /// Accumulates [deltas] into internal state until the stream completes.
  Future<void> consume(Stream<ScoreDelta> deltas) async {
    await for (final delta in deltas) {
      // The roster is authoritative: a delta naming an id that was never on it
      // is dropped, so the board cannot grow a row with no name behind it.
      final current = _scores[delta.playerId];
      if (current == null) continue;
      _scores[delta.playerId] = current + delta.amount;
      // Snapshot taken here, at mutation time. Reading `_scores` when the event
      // is finally delivered would let a buffered change see later mutations
      // too, silently collapsing two boards into one.
      _changes.add(Map.of(_scores));
    }
  }

  /// Releases the change stream. Only meaningful in tests; in the app the board
  /// lives as long as the process.
  Future<void> dispose() => _changes.close();
}

bool _sameBoard(List<LeaderboardEntry> a, List<LeaderboardEntry> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
