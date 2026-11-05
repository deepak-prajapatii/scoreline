import 'dart:async';
import 'dart:isolate';

import 'package:engine/engine.dart';
import 'package:leaderboard/leaderboard.dart';

/// A running match: the engine and the board, both living in a background
/// isolate, and the finished boards they post back.
///
/// This is the counterpart of the Android app's `CoroutineScope(SupervisorJob()
/// + Dispatchers.Default)`. Generating events, accumulating totals and
/// re-ranking all happen off the UI isolate; the UI only ever receives a board
/// that is already sorted and ready, and paints it.
///
/// That matters because `rank()` is the one piece of work that grows with the
/// number of players. Kept off the UI isolate its cost scales with the roster;
/// run on the UI isolate it would compete with the frame budget, and a bigger
/// roster would show up as dropped frames.
///
/// ponytail: at eight players a `Timer` on the UI isolate would be
/// indistinguishable, and the isolate costs a spawn plus a copy of every board
/// across the port. It is here for parity with the reference's threading claim
/// and because it is the only shape that still holds at a large roster. If the
/// roster is never going to grow, delete this file and construct the two
/// engines directly in `lib/di/app_container.dart`.
class Match {
  Match._(this._isolate, this._receivePort) {
    _subscription = _receivePort.cast<List<LeaderboardEntry>>().listen((board) {
      _latest = board;
      _controller.add(board);
    });
  }

  /// Spawns the match. Call once per process — the engine is seeded, so a
  /// second spawn would replay the identical event sequence onto a second
  /// board.
  ///
  /// [intervalMillis] exists so tests can run the match on a fast clock; the
  /// app never passes it.
  static Future<Match> start(
    List<Player> roster, {
    int seed = 1234,
    ({int min, int max}) intervalMillis = (min: 500, max: 2000),
  }) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _runMatch,
      _MatchRequest(receivePort.sendPort, roster, seed, intervalMillis),
      debugName: 'scoreline-match',
    );
    return Match._(isolate, receivePort);
  }

  final Isolate _isolate;
  final ReceivePort _receivePort;
  late final StreamSubscription<List<LeaderboardEntry>> _subscription;

  final StreamController<List<LeaderboardEntry>> _controller =
      StreamController<List<LeaderboardEntry>>.broadcast();

  // The last board that crossed the port. Held here so a screen that goes away
  // and comes back is handed the current standings immediately rather than
  // waiting up to two seconds for the next event — the UI-side half of "totals
  // live below the UI".
  //
  // Null until the first board arrives, and nothing is emitted while it is:
  // handing out an empty board would be publishing a standings list that is
  // wrong rather than merely absent.
  List<LeaderboardEntry>? _latest;

  /// The ranked board. Emits the current standings on listen, then every board
  /// that differs from the one before it.
  Stream<List<LeaderboardEntry>> get boards =>
      Stream<List<LeaderboardEntry>>.multi((controller) {
        final subscription = _controller.stream.listen(controller.add);
        final latest = _latest;
        if (latest != null) controller.add(latest);
        controller.onCancel = subscription.cancel;
      });

  /// Tears the match down. Never called in the app — the match is meant to
  /// outlive every screen, like a tournament server that does not pause because
  /// one spectator looked away. Tests use it so they do not leak an isolate.
  Future<void> stop() async {
    await _subscription.cancel();
    _receivePort.close();
    _isolate.kill(priority: Isolate.immediate);
    await _controller.close();
  }
}

/// Payload for [Isolate.spawn], which takes exactly one argument.
class _MatchRequest {
  const _MatchRequest(
    this.sendPort,
    this.roster,
    this.seed,
    this.intervalMillis,
  );

  final SendPort sendPort;
  final List<Player> roster;
  final int seed;
  final ({int min, int max}) intervalMillis;
}

/// Runs in the background isolate.
///
/// This is the only code that knows both `ScoreEvent` and `ScoreDelta` exist.
/// That single `map` is the entire price of `package:engine` and
/// `package:leaderboard` not depending on each other — the board can be fed
/// from a websocket, a replay file or a test fixture by changing this line and
/// nothing else.
Future<void> _runMatch(_MatchRequest request) async {
  final engine = SimulatedScoreEngine(
    request.roster,
    seed: request.seed,
    intervalMillis: request.intervalMillis,
  );
  final board = LeaderboardEngine([
    for (final player in request.roster) (player.id, player.name),
  ]);

  board.rankings.listen(request.sendPort.send);

  await board.consume(
    engine.events.map((event) => ScoreDelta(event.playerId, event.delta)),
  );
}
