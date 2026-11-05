import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:leaderboard/leaderboard.dart';
import 'package:scoreline/theme/arena_theme.dart';

const _pulse = Duration(milliseconds: 900);
const _cardRadius = 16.0;
const _glowStroke = 1.5;
const _cardTintAlpha = 0.10;
const _barAlpha = 0.13;
const _avatarSaturation = 0.62;
const _avatarValue = 0.58;
const _tiedRankAlpha = 0.35;
const _hueDegrees = 360;
const _hueStep = 137;

/// Height of one row. Fixed so the board can lay rows out by position and slide
/// them when ranks swap — see `LeaderboardScreen`.
const rowHeight = 64.0;

/// One row of the board: rank badge, avatar, name, transient gain chip and
/// score.
class LeaderboardRow extends StatefulWidget {
  /// Creates a row.
  const LeaderboardRow({
    required this.entry,
    required this.topScore,
    required this.tiedWithAbove,
    super.key,
  });

  /// The player, score and rank this row shows.
  final LeaderboardEntry entry;

  /// The current leader's score, deliberately a listenable rather than an
  /// `int`.
  ///
  /// As a plain value it would be a changed argument for *every* row each time
  /// the leader scored, rebuilding the whole visible board on every tick. As a
  /// listenable the parameter's identity never changes, so the row does not
  /// rebuild; the value is read inside the painter, which invalidates paint
  /// only. This is the Flutter spelling of passing Compose a `State<Long>` and
  /// reading it in `drawBehind`.
  final ValueListenable<int> topScore;

  /// Dims the rank numeral so a five-way tie on rank 4 reads as one group
  /// rather than five identical numbers.
  final bool tiedWithAbove;

  @override
  State<LeaderboardRow> createState() => _LeaderboardRowState();
}

class _LeaderboardRowState extends State<LeaderboardRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pulse,
    // Starts completed, so `1 - value` is 0: at rest there is no glow. This is
    // also what stops the whole board flashing at launch.
    value: 1,
  );

  // Seeded with the score this row was built with, so "first build" and "the
  // score changed" stay distinguishable. That is what stops the whole board
  // flashing at launch.
  //
  // Assigned in initState, not as a `late` initialiser: a `late` field
  // initialises on first *read*, and the first read is inside didUpdateWidget —
  // where `widget` already points at the new entry. It would seed itself with
  // the score it is supposed to be compared against, and every row's first gain
  // would silently produce no chip and no glow.
  late int _previous;
  int _gained = 0;

  @override
  void initState() {
    super.initState();
    _previous = widget.entry.score;
  }

  @override
  void didUpdateWidget(LeaderboardRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.score != _previous) {
      _gained = widget.entry.score - _previous;
      _previous = widget.entry.score;
      // From zero, not toward a target: a pulse is an instant onset and a
      // decay. An implicitly animated opacity cannot express that — it only
      // eases toward its current target, so it would fade in and stay.
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final accent = _rankColor(entry.rank);
    final tint = _avatarColor(entry.playerId);
    final text = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: 'Rank ${entry.rank}, ${entry.name}, ${entry.score} points',
      child: CustomPaint(
        // Card tint, leader-relative score bar and the just-changed glow ring,
        // in one paint pass. Everything fast-changing is read *here* — the
        // leader's score and the pulse both. Reading either during build would
        // rebuild the row on every frame of the animation and on every point
        // the leader scores.
        painter: _ArenaCard(
          tint: tint,
          accent: accent,
          score: entry.score,
          topScore: widget.topScore,
          pulse: _controller,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${entry.rank}',
                  style: text.titleMedium?.copyWith(
                    color: widget.tiedWithAbove
                        ? accent.withValues(alpha: _tiedRankAlpha)
                        : accent,
                  ),
                ),
              ),
              _Avatar(name: entry.name, tint: tint),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    entry.name,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              _GainChip(gained: _gained, pulse: _controller),
              Text('${entry.score}', style: text.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArenaCard extends CustomPainter {
  _ArenaCard({
    required this.tint,
    required this.accent,
    required this.score,
    required this.topScore,
    required this.pulse,
    // The two things that change every frame drive repaint directly, without
    // going through the element tree.
  }) : super(repaint: Listenable.merge([topScore, pulse]));

  final Color tint;
  final Color accent;
  final int score;
  final ValueListenable<int> topScore;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(_cardRadius);
    final card = RRect.fromRectAndRadius(Offset.zero & size, radius);

    canvas.drawRRect(
      card,
      Paint()..color = tint.withValues(alpha: _cardTintAlpha),
    );

    final leader = topScore.value;
    final barWidth = leader > 0 ? size.width * (score / leader) : 0.0;
    // Below one corner diameter the rounded rect degenerates into a sliver
    // that reads as a rendering artefact rather than as "almost no score".
    // Nothing is the honest thing to draw there.
    if (barWidth >= _cardRadius * 2) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & Size(barWidth, size.height),
          radius,
        ),
        Paint()..color = accent.withValues(alpha: _barAlpha),
      );
    }

    final glow = 1 - pulse.value;
    if (glow > 0) {
      canvas.drawRRect(
        card.deflate(_glowStroke / 2),
        Paint()
          ..color = gain.withValues(alpha: glow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _glowStroke,
      );
    }
  }

  @override
  bool shouldRepaint(_ArenaCard oldDelegate) =>
      score != oldDelegate.score ||
      tint != oldDelegate.tint ||
      accent != oldDelegate.accent;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.tint});

  final String name;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      name.characters.take(1).toString(),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
  );
}

/// The transient "+37". Its own widget so that when the pulse runs only this
/// fades, through an opacity layer, rather than the whole row rebuilding.
class _GainChip extends StatelessWidget {
  const _GainChip({required this.gained, required this.pulse});

  final int gained;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    if (gained <= 0) return const SizedBox.shrink();
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(pulse),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          '+$gained',
          style: const TextStyle(
            color: gain,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

Color _rankColor(int rank) => switch (rank) {
  1 => gold,
  2 => silver,
  3 => bronze,
  _ => onSurfaceDim,
};

/// A stable per-player colour with no domain field behind it: the id is fixed
/// for the life of the board, so the same player is always the same hue.
///
/// The hue-step multiply is load-bearing. Ids are "p1".."p8", whose hashes are
/// *consecutive integers*, so a plain `hash % 360` spread all eight players
/// across seven degrees of hue and every avatar came out the same purple.
/// Multiplying by a step near the golden angle (137°) before wrapping scatters
/// neighbouring ids to opposite sides of the wheel.
Color _avatarColor(String playerId) {
  final hue = (_jvmHashCode(playerId) * _hueStep).remainder(_hueDegrees).abs();
  return HSVColor.fromAHSV(
    1,
    hue.toDouble(),
    _avatarSaturation,
    _avatarValue,
  ).toColor();
}

/// Java's `String.hashCode`, reimplemented.
///
/// Dart's own `String.hashCode` is a different, deliberately unspecified
/// function, so using it here would give the Flutter build a different set of
/// avatar colours than the Android one. `remainder` rather than `%` for the
/// same reason: Dart's `%` always returns a non-negative result where Kotlin's
/// keeps the sign, and the hue is taken from `abs()` of the signed remainder.
int _jvmHashCode(String value) {
  var hash = 0;
  for (final unit in value.codeUnits) {
    hash = (31 * hash + unit) & 0xFFFFFFFF;
  }
  // Back to a signed 32-bit int, which is what Java hands out.
  return hash >= 0x80000000 ? hash - 0x100000000 : hash;
}
