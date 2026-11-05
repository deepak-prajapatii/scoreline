import 'dart:async';

import 'package:leaderboard/leaderboard.dart';
import 'package:test/test.dart';

const _roster = [
  ('p1', 'Ada'),
  ('p2', 'Grace'),
  ('p3', 'Linus'),
  ('p4', 'Barbara'),
];

/// Deltas are fed from plain `Stream.fromIterable`, never from `package:engine`
/// — this package has no dependency on it and the tests must not quietly add
/// one.
void main() {
  test('a fresh board shows the whole roster at zero, all tied for first',
      () async {
    final board = await LeaderboardEngine(_roster).rankings.first;

    expect(board.map((e) => e.playerId), ['p1', 'p2', 'p3', 'p4']);
    expect(board.map((e) => e.score), [0, 0, 0, 0]);
    expect(board.map((e) => e.rank), [1, 1, 1, 1]);
  });

  test('deltas accumulate into totals and rank with the tie skipped', () async {
    final board = LeaderboardEngine(_roster);

    await board.consume(
      Stream.fromIterable([
        ScoreDelta('p1', 500),
        ScoreDelta('p2', 300),
        ScoreDelta('p3', 300),
        ScoreDelta('p4', 100),
      ]),
    );

    expect(await board.rankings.first, const [
      LeaderboardEntry('p1', 'Ada', 500, 1),
      LeaderboardEntry('p2', 'Grace', 300, 2),
      LeaderboardEntry('p3', 'Linus', 300, 2),
      LeaderboardEntry('p4', 'Barbara', 100, 4),
    ]);
  });

  test('repeated deltas for one player sum instead of replacing', () async {
    final board = LeaderboardEngine(_roster);

    await board.consume(
      Stream.fromIterable([ScoreDelta('p1', 10), ScoreDelta('p1', 32)]),
    );

    final entry =
        (await board.rankings.first).singleWhere((e) => e.playerId == 'p1');
    expect(entry.score, 42);
  });

  test('a delta for an id that was never on the roster is dropped', () async {
    final board = LeaderboardEngine(_roster);
    final before = await board.rankings.first;

    await board.consume(Stream.fromIterable([ScoreDelta('ghost', 999)]));

    // Unchanged, and no nameless fifth row.
    expect(await board.rankings.first, before);
  });

  // The fold-in-the-stream regression. With the accumulator inside the stream
  // the board would reset to zero every time the last listener went away —
  // every rotation, every return from background.
  test('a new listener sees the accumulated board, not a fresh one', () async {
    final board = LeaderboardEngine(_roster);
    await board.consume(
      Stream.fromIterable([ScoreDelta('p1', 10), ScoreDelta('p2', 30)]),
    );

    final first = await board.rankings.first; // listener arrives and leaves
    final second = await board.rankings.first; // a second one arrives

    expect(first, second);
    expect(second.map((e) => e.score), [30, 10, 0, 0]);
  });

  test('a delta that changes nothing emits nothing downstream', () async {
    final board = LeaderboardEngine(_roster);
    final emissions = <List<LeaderboardEntry>>[];
    final subscription = board.rankings.listen(emissions.add);

    // Pumped between each: changes arriving faster than the listener drains are
    // conflated into one board, exactly as StateFlow conflates. That is correct
    // — the screen only ever wants the latest — but it would hide the thing
    // under test here, which is that the ghost produces no board at all.
    await board.consume(Stream.fromIterable([ScoreDelta('p1', 10)]));
    await pumpEventQueue();
    await board.consume(Stream.fromIterable([ScoreDelta('ghost', 99)]));
    await pumpEventQueue();
    await board.consume(Stream.fromIterable([ScoreDelta('p2', 5)]));
    await pumpEventQueue();

    // The initial board plus two real changes. The ghost cost the UI no
    // rebuild.
    expect(emissions, hasLength(3));
    await subscription.cancel();
    await board.dispose();
  });

  test('consume stops when its source stream is cancelled', () async {
    final board = LeaderboardEngine(_roster);
    final controller = StreamController<ScoreDelta>();

    final consuming = board.consume(controller.stream);
    controller.add(ScoreDelta('p1', 5));
    await Future<void>.delayed(Duration.zero);

    final entry =
        (await board.rankings.first).singleWhere((e) => e.playerId == 'p1');
    expect(entry.score, 5);

    await controller.close();
    await consuming; // completes rather than hanging
  });

  test('a roster with duplicate ids is rejected at construction', () {
    expect(
      () => LeaderboardEngine(const [('p1', 'Ada'), ('p1', 'Grace')]),
      throwsArgumentError,
    );
  });

  test('a negative delta is rejected at construction', () {
    expect(() => ScoreDelta('p1', -1), throwsArgumentError);
  });

  test('a zero delta is rejected at construction', () {
    expect(() => ScoreDelta('p1', 0), throwsArgumentError);
  });
}
