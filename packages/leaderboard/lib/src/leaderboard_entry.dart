import 'package:equatable/equatable.dart';

/// One row of the ranked board: a player's id, display name, running score and
/// current rank.
///
/// Extends [Equatable] because Dart has no `data class`. Value equality is not
/// cosmetic here — `LeaderboardEngine.rankings` compares consecutive boards to
/// decide whether to emit at all, and identity equality would never hold
/// because ranking allocates fresh entries on every event.
class LeaderboardEntry extends Equatable {
  /// Creates a row of the board.
  const LeaderboardEntry(this.playerId, this.name, this.score, this.rank);

  /// Stable id of the player this row belongs to. Used as the widget key, which
  /// is what makes a rank swap animate as one row moving.
  final String playerId;

  /// Display name.
  final String name;

  /// Running total. Only ever increases.
  final int score;

  /// Competition rank, 1-based. Tied players share a rank.
  final int rank;

  @override
  List<Object?> get props => [playerId, name, score, rank];
}
