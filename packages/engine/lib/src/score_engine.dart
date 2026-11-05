import 'package:equatable/equatable.dart';

/// A player on the roster.
class Player extends Equatable {
  /// Creates a player.
  const Player(this.id, this.name);

  /// Stable identifier.
  final String id;

  /// Display name.
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// A single score change. [delta] is always greater than zero — scores only
/// ever increase.
class ScoreEvent extends Equatable {
  /// Creates a score event.
  const ScoreEvent(this.playerId, this.delta);

  /// Id of the player who scored.
  final String playerId;

  /// Points gained.
  final int delta;

  @override
  List<Object?> get props => [playerId, delta];
}

/// Source of score updates. The stand-in for a match backend; a websocket
/// implementation attaches here without touching any consumer.
abstract interface class ScoreEngine {
  /// The live event stream. Cold: listening starts a fresh match.
  Stream<ScoreEvent> get events;
}
