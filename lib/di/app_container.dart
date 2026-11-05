import 'dart:async';

import 'package:engine/engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leaderboard/leaderboard.dart';
import 'package:scoreline/isolate/match_isolate.dart';

/// Composition root.
///
/// The Android app hand-rolls this as a single `object AppContainer`, on the
/// grounds that wiring three objects together does not need Hilt or Koin. Here
/// it is Riverpod, because on Flutter the same library that does the wiring
/// also does the state exposure — [rankingsProvider] is simultaneously the DI
/// graph and the ViewModel.
///
/// The roster. Fixed for the life of the board.
final rosterProvider = Provider<List<Player>>(
  (ref) => const [
    Player('p1', 'Damon'),
    Player('p2', 'Elena'),
    Player('p3', 'Elijah'),
    Player('p4', 'Katherine'),
    Player('p5', 'Alaric'),
    Player('p6', 'Hope'),
    Player('p7', 'Niklaus'),
    Player('p8', 'Ryna Cruz'),
  ],
);

/// The running match, spawned exactly once per process.
///
/// Deliberately **not** auto-disposed, which is the point: the match keeps
/// running while the user is elsewhere, like a tournament server. It captures a
/// list of two-string values and an int seed — no `BuildContext`, no widget —
/// so "never disposed" means "dies with the process", not "leaks".
///
/// It must never be started from a widget's `initState`. `SimulatedScoreEngine`
/// is seeded and rebuilds its `Random` per listen, so a second start would
/// replay the identical event sequence from event #1 onto an already-populated
/// board and silently double every score.
///
/// This is also the swap point: a websocket implementation of `ScoreEngine`
/// attaches inside [Match] and nothing else in the app moves.
final matchProvider = FutureProvider<Match>(
  (ref) => Match.start(ref.watch(rosterProvider)),
);

/// How long the board keeps ranking after the last listener goes away.
///
/// A rotation drops the listener for milliseconds, far inside this window, so
/// the upstream is never restarted. A genuine background stops the ranking
/// after five seconds. Restarting costs nothing, because the score map lives in
/// the isolate's `LeaderboardEngine` and not in this stream — a ten-minute
/// background therefore costs exactly one `rank()` call on return, not one per
/// event missed.
const _keepRankingFor = Duration(seconds: 5);

/// The ranked board, as the screen consumes it.
///
/// `autoDispose` plus a [_keepRankingFor] grace period is Riverpod's spelling
/// of Kotlin's `stateIn(scope, SharingStarted.WhileSubscribed(5_000),
/// emptyList())` — and like that call it retains the last board rather than
/// reverting to an empty one when it stops.
final rankingsProvider = StreamProvider.autoDispose<List<LeaderboardEntry>>((
  ref,
) {
  final link = ref.keepAlive();
  Timer? release;

  ref
    ..onCancel(() => release = Timer(_keepRankingFor, link.close))
    ..onResume(() {
      release?.cancel();
      release = null;
    })
    ..onDispose(() => release?.cancel());

  return Stream.fromFuture(ref.watch(matchProvider.future))
      .asyncExpand((match) => match.boards);
});
