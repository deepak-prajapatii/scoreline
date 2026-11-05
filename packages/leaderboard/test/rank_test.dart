import 'package:leaderboard/src/leaderboard_entry.dart';
// Reaching into src/ is legal here and only here: rank() is this package's
// equivalent of Kotlin `internal`, visible to its own tests and to nothing
// else.
import 'package:leaderboard/src/ranking.dart';
import 'package:test/test.dart';

const _names = {
  'p1': 'Ada',
  'p2': 'Grace',
  'p3': 'Linus',
  'p4': 'Barbara',
  'p5': 'Alan',
};

/// The whole ranking rule is testable by calling a function with a map — no
/// streams, no fake clock, no widgets. That is what "ranking logic must not
/// live in the UI" buys.
void main() {
  test('a tie shares a rank and the next rank skips it', () {
    final ranked = rank(
      {'p1': 500, 'p2': 300, 'p3': 300, 'p4': 100},
      _names,
    );

    expect(ranked.map((e) => e.playerId), ['p1', 'p2', 'p3', 'p4']);
    expect(ranked.map((e) => e.rank), [1, 2, 2, 4]);
  });

  test('a three-way tie skips three ranks', () {
    final scores = {'p1': 500, 'p2': 300, 'p3': 300, 'p4': 300, 'p5': 100};

    expect(rank(scores, _names).map((e) => e.rank), [1, 2, 2, 2, 5]);
  });

  test('everyone tied is everyone at rank 1', () {
    final scores = {'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0};

    expect(rank(scores, _names).map((e) => e.rank), [1, 1, 1, 1]);
  });

  test('tied players order by id ascending, not by insertion order', () {
    final scores = {'p3': 300, 'p1': 300, 'p2': 300};

    expect(rank(scores, _names).map((e) => e.playerId), ['p1', 'p2', 'p3']);
  });

  // The flicker regression. Without the id tie-break two players on the same
  // score sit in an unspecified relative order, so the same board recomputes
  // into a different list and the rows swap forever while nothing is changing.
  test('the output depends only on the pairs, not on map iteration order', () {
    final a = {'p1': 300, 'p2': 300, 'p3': 500, 'p4': 300};
    final b = {'p4': 300, 'p3': 500, 'p2': 300, 'p1': 300};

    expect(rank(a, _names), rank(b, _names));
  });

  test('a single player is rank 1', () {
    expect(rank({'p1': 42}, _names).map((e) => e.rank), [1]);
  });

  test('an empty board ranks to an empty list', () {
    expect(rank({}, _names), isEmpty);
  });

  test('entries carry the name joined by id', () {
    final ranked = rank({'p1': 500, 'p2': 300}, _names);

    expect(ranked.map((e) => e.name), ['Ada', 'Grace']);
  });

  test('a player with no name falls back to the id instead of throwing', () {
    expect(rank({'stranger': 10}, _names).single.name, 'stranger');
  });

  test('entries compare by value, which is what distinct relies on', () {
    expect(
      const LeaderboardEntry('p1', 'Ada', 500, 1),
      const LeaderboardEntry('p1', 'Ada', 500, 1),
    );
  });
}
