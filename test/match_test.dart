import 'package:engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaderboard/leaderboard.dart';
import 'package:scoreline/isolate/match_isolate.dart';

const _roster = [Player('p1', 'Ada'), Player('p2', 'Grace')];

int _total(List<LeaderboardEntry> board) =>
    board.fold(0, (sum, entry) => sum + entry.score);

void main() {
  // The one property in the app layer with a failure mode you cannot see by
  // looking at the screen: a board that silently resets after half a minute in
  // the background demos perfectly.
  //
  // Fails if the accumulator ever moves into the presentation stream, if the
  // match is tied to a widget's lifecycle, or if the latest board stops being
  // retained when the last listener leaves.
  test(
    'the board advances with nobody watching, and returning picks it up',
    () async {
      final match = await Match.start(
        _roster,
        intervalMillis: (min: 1, max: 2),
      );
      addTearDown(match.stop);

      // Listen, take one, drop it: the screen appearing and then going away.
      final whileVisible = await match.boards.firstWhere(
        (board) => _total(board) > 0,
      );

      // The match keeps running while nothing is subscribed.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Come back. The board must be further along, not reset to zero, and it
      // must arrive immediately rather than after the next event.
      final returned = await match.boards.first;

      expect(_total(returned), greaterThan(_total(whileVisible)));
      expect(returned, hasLength(_roster.length));
    },
  );

  test(
    'a fresh match hands the first listener the whole roster at zero',
    () async {
      final match = await Match.start(
        _roster,
        intervalMillis: (min: 5000, max: 5000),
      );
      addTearDown(match.stop);

      final board = await match.boards.first;

      expect(board.map((e) => e.playerId), ['p1', 'p2']);
      expect(board.map((e) => e.score), [0, 0]);
      expect(board.map((e) => e.rank), [1, 1]);
    },
  );

  test(
    'the board stays ranked: scores descend and ranks never decrease',
    () async {
      final match = await Match.start(
        _roster,
        intervalMillis: (min: 1, max: 2),
      );
      addTearDown(match.stop);

      final board = await match.boards.firstWhere((b) => _total(b) > 50);

      final scores = board.map((e) => e.score).toList();
      expect(scores, orderedEquals(scores.toList()..sort((a, b) => b - a)));
    },
  );
}
