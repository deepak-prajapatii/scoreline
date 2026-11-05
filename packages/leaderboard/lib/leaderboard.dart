/// Accumulates score deltas into running totals and exposes the ranked board.
///
/// `rank()` is deliberately **not** exported. It lives in
/// `lib/src/ranking.dart`, which is this package's equivalent of Kotlin's
/// `internal`: the app can see the finished board and nothing else, and
/// reaching past this barrel file trips the `implementation_imports` lint.
/// "Ranking must not live in the UI or the ViewModel" is therefore enforced by
/// visibility, not promised in a comment.
library;

export 'src/leaderboard_engine.dart' show LeaderboardEngine;
export 'src/leaderboard_entry.dart' show LeaderboardEntry;
export 'src/score_delta.dart' show ScoreDelta;
