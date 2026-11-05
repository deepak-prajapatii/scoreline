import 'package:flutter/material.dart';
import 'package:scoreline/theme/arena_theme.dart';
import 'package:scoreline/ui/scoreline_logo.dart';

const _pulse = Duration(milliseconds: 900);
const _pulseMinAlpha = 0.25;
const _dotSize = 7.0;
const _ruleAlpha = 0.10;

/// The board's title bar: logo, wordmark, live badge and the column header
/// rule.
///
/// The reference design this borrows from also showed a countdown and a prize
/// pool; both are omitted because this system has neither, and a UI-side clock
/// is specifically what the brief lists as *not* wanted ("fake real-time
/// updates (timers in UI)").
class LeaderboardHeader extends StatelessWidget {
  /// Creates the header.
  const LeaderboardHeader({
    required this.playerCount,
    required this.totalPoints,
    super.key,
  });

  /// Real player count derived from the board, not decoration.
  final int playerCount;

  /// Real total-points-in-play, likewise derived, not decoration.
  final int totalPoints;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ScorelineLogo(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SCORELINE',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$playerCount players · $totalPoints pts in play',
                      style: const TextStyle(fontSize: 12, color: onSurfaceDim),
                    ),
                  ],
                ),
              ),
              const _LiveBadge(),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RANK  PLAYER',
                style: text.labelSmall?.copyWith(color: onSurfaceDim),
              ),
              Text(
                'SCORE',
                style: text.labelSmall?.copyWith(color: onSurfaceDim),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 1,
            color: onSurfaceDim.withValues(alpha: _ruleAlpha),
          ),
        ],
      ),
    );
  }
}

/// The one piece of motion that is not driven by data: it says the stream is
/// open, nothing more.
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pulse,
  )..repeat(reverse: true);

  late final Animation<double> _alpha = Tween<double>(
    begin: 1,
    end: _pulseMinAlpha,
  ).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      // The dot repaints; nothing rebuilds. FadeTransition drives an opacity
      // layer straight from the controller.
      FadeTransition(
        opacity: _alpha,
        child: Container(
          width: _dotSize,
          height: _dotSize,
          decoration: const BoxDecoration(color: gain, shape: BoxShape.circle),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        'LIVE',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: gain),
      ),
    ],
  );
}
