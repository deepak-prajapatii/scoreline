import 'dart:math';

import 'package:engine/src/score_engine.dart';

/// Deterministic fake match engine. The same seed replays the same sequence of
/// (player, delta, interval) triples.
///
/// Emits deltas rather than absolute scores, so "a score only increases" is a
/// property of the type — a positive int added to a running total cannot
/// decrease it — instead of a rule every caller has to remember. The engine
/// therefore holds no score state, needs no synchronisation and has no reset
/// path.
class SimulatedScoreEngine implements ScoreEngine {
  /// Creates a simulator over [players].
  SimulatedScoreEngine(
    this.players, {
    required this.seed,
    this.intervalMillis = (min: 500, max: 2000),
    this.deltaRange = (min: 1, max: 50),
  }) {
    if (players.isEmpty) {
      throw ArgumentError('players must not be empty');
    }
    if (deltaRange.min < 1 || deltaRange.max < deltaRange.min) {
      throw ArgumentError(
        'deltaRange must be positive — scores only ever increase — '
        'but was $deltaRange',
      );
    }
    if (intervalMillis.min < 0 || intervalMillis.max < intervalMillis.min) {
      throw ArgumentError(
        'intervalMillis must be a non-negative range, but was $intervalMillis',
      );
    }
  }

  /// The roster events are drawn from.
  final List<Player> players;

  /// Fixes the sequence. Same seed, same match.
  final int seed;

  /// Inclusive delay range between events.
  final ({int min, int max}) intervalMillis;

  /// Inclusive range of points awarded per event.
  final ({int min, int max}) deltaRange;

  @override
  Stream<ScoreEvent> get events async* {
    // Built inside the generator, not held as a field: each listen restarts
    // from the seed rather than sharing mutable RNG state, so a second listener
    // sees the same stream as the first.
    final random = Random(seed);
    while (true) {
      await Future<void>.delayed(
        Duration(milliseconds: _between(random, intervalMillis)),
      );
      final player = players[random.nextInt(players.length)];
      yield ScoreEvent(player.id, _between(random, deltaRange));
    }
  }

  static int _between(Random random, ({int min, int max}) range) =>
      range.min + random.nextInt(range.max - range.min + 1);
}
