import 'package:equatable/equatable.dart';

/// The input port: what this module is willing to consume.
///
/// Deliberately not the engine's `ScoreEvent` — the consumer owns the contract
/// it consumes, so the board is feedable from a websocket, a replay file or a
/// test fixture without editing either package. The single `map` in the
/// composition root that adapts one to the other is the entire price of that
/// independence.
class ScoreDelta extends Equatable {
  /// Creates a delta.
  ///
  /// Throws [ArgumentError] if [amount] is not positive. A real throw rather
  /// than an `assert`, because asserts are stripped from release AOT builds and
  /// this is a trust boundary: deltas arrive from whatever engine is plugged
  /// in.
  ScoreDelta(this.playerId, this.amount) {
    if (amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'must be positive — scores only ever increase',
      );
    }
  }

  /// Id of the player who scored.
  final String playerId;

  /// Points gained. Always greater than zero.
  final int amount;

  @override
  List<Object?> get props => [playerId, amount];
}
