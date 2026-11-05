/// The match backend stand-in: emits score events and knows nothing about
/// leaderboards.
///
/// Pure Dart. It has no `flutter` dependency, so `import 'package:flutter/...'`
/// here does not compile — the same guarantee `:engine` gets on Android from
/// being a `java-library` with no Android SDK on its classpath.
library;

export 'src/score_engine.dart' show Player, ScoreEngine, ScoreEvent;
export 'src/simulated_score_engine.dart' show SimulatedScoreEngine;
