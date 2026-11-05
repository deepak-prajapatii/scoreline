import 'package:engine/engine.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

const _roster = [
  Player('p1', 'Ada'),
  Player('p2', 'Grace'),
  Player('p3', 'Linus'),
];

/// Every test collects under [fakeAsync]'s virtual clock — the direct
/// counterpart of `runTest`'s virtual time on the Kotlin side — so a 2000 ms
/// interval costs microseconds and 200 events cost nothing. `take(n)` is what
/// terminates the engine's infinite loop.
void main() {
  test('each listen replays from the seed', () {
    final engine = SimulatedScoreEngine(_roster, seed: 1234);

    final first = _drain(engine, 20);
    final second = _drain(engine, 20);

    expect(first, second);
  });

  test('a different seed produces a different sequence', () {
    final a = _drain(SimulatedScoreEngine(_roster, seed: 1), 20);
    final b = _drain(SimulatedScoreEngine(_roster, seed: 2), 20);

    expect(a, isNot(b));
  });

  test('every delta lands inside deltaRange, endpoints included', () {
    const range = (min: 3, max: 7);
    final events = _drain(
      SimulatedScoreEngine(_roster, seed: 99, deltaRange: range),
      200,
    );
    final deltas = events.map((e) => e.delta).toList();

    expect(deltas.where((d) => d < range.min || d > range.max), isEmpty);
    // Both endpoints must be reachable — catches an exclusive upper bound.
    expect(deltas, contains(range.min));
    expect(deltas, contains(range.max));
  });

  test('intervals land inside intervalMillis, endpoints included', () {
    // Deliberately narrow: over 200 events both endpoints of a 3-value range
    // are certain, which is what makes the inclusive-bound assertion
    // meaningful.
    const range = (min: 10, max: 12);
    final emittedAt = <int>[];

    fakeAsync((async) {
      final subscription = SimulatedScoreEngine(
        _roster,
        seed: 7,
        intervalMillis: range,
      )
          .events
          .take(200)
          .listen((_) => emittedAt.add(async.elapsed.inMilliseconds));
      async.elapse(const Duration(seconds: 10));
      subscription.cancel();
    });

    final gaps = [
      emittedAt.first,
      for (var i = 1; i < emittedAt.length; i++)
        emittedAt[i] - emittedAt[i - 1],
    ];
    expect(gaps.where((g) => g < range.min || g > range.max), isEmpty);
    expect(gaps, contains(range.min));
    expect(gaps, contains(range.max));
  });

  test('every event names a player from the roster', () {
    final seen = _drain(SimulatedScoreEngine(_roster, seed: 42), 200)
        .map((e) => e.playerId)
        .toSet();

    // Equality both ways: no stranger ids, and no player is unreachable.
    expect(seen, _roster.map((p) => p.id).toSet());
  });

  test('an empty roster is rejected at construction', () {
    expect(
      () => SimulatedScoreEngine(const [], seed: 1),
      throwsArgumentError,
    );
  });

  test('a non-positive delta range is rejected at construction', () {
    expect(
      () =>
          SimulatedScoreEngine(_roster, seed: 1, deltaRange: (min: 0, max: 5)),
      throwsArgumentError,
    );
  });

  test('a negative interval range is rejected at construction', () {
    expect(
      () => SimulatedScoreEngine(
        _roster,
        seed: 1,
        intervalMillis: (min: -1, max: 5),
      ),
      throwsArgumentError,
    );
  });
}

/// Collects [count] events under a virtual clock and returns them.
List<ScoreEvent> _drain(SimulatedScoreEngine engine, int count) {
  final events = <ScoreEvent>[];
  fakeAsync((async) {
    final subscription = engine.events.take(count).listen(events.add);
    async.elapse(const Duration(minutes: 10));
    subscription.cancel();
  });
  return events;
}
