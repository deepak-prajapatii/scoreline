# Scoreline — Real-Time Leaderboard (Flutter)

A simulated match engine emits score events; a leaderboard package accumulates and ranks them; a
Flutter screen renders the board live on **Android and iOS**. The three are separate Dart packages,
and the two that hold the logic cannot see Flutter or each other.

This is a port of the native Android app in
[`scoreline-leaderboard`](../../scoreline-leaderboard). Every Android concept it uses has a named
Flutter counterpart, and the full mapping — including the parts of a typical Android stack this app
does *not* use — is in [Android → Flutter](#android--flutter).

## How to run

```bash
flutter pub get
flutter run --flavor dev         # Android — the flavor is required, see Flavors
flutter run                      # iOS — no flavors on that side
```

```bash
flutter test                     # widget and match tests
(cd packages/leaderboard && dart test)   # 20 tests, plain Dart VM, no Flutter
(cd packages/engine && dart test)        # 8 tests, plain Dart VM, no Flutter
flutter analyze                  # what CI would run
```

Full command list is under [Commands](#commands); the three Android builds are under
[Flavors](#flavors); toolchain versions are under [Requirements](#requirements).

## Packages

| Package | Type | Owns |
|---|---|---|
| `packages/engine` | pure Dart | The match backend stand-in. Emits `ScoreEvent`s. |
| `packages/leaderboard` | pure Dart | Accumulates deltas into totals and ranks them. |
| root (`lib/`) | Flutter app | UI, providers, and the composition root that wires the other two. |

`packages/engine` and `packages/leaderboard` are plain Dart packages. "UI-agnostic" is not a
convention here — neither declares a dependency on `flutter`, so a stray
`import 'package:flutter/material.dart'` is a compile error:

```
error - lib/src/ranking.dart:1:8 - Target of URI doesn't exist: 'package:flutter/material.dart'
```

That is the same guarantee the Android build gets from `:engine` and `:leaderboard` being
`java-library` modules with no Android SDK on their compile classpath, obtained the same way — from
the build graph, not from a folder naming convention.

**`packages/leaderboard` does not depend on `packages/engine`.** It declares its own input type,
`ScoreDelta` (`lib/src/score_delta.dart`), and will consume deltas from anywhere: a websocket, a
replay file, a test fixture. The single `map` in `lib/isolate/match_isolate.dart` that turns a
`ScoreEvent` into a `ScoreDelta` is the entire cost of that independence.

## Architecture

### The three layers

| Layer | Package | Responsibility |
|---|---|---|
| Data / Engine | `packages/engine` | Produces score events. Knows nothing about leaderboards. |
| Domain | `packages/leaderboard` | Accumulates totals and applies the ranking rules. Knows nothing about where events come from, or about Flutter. |
| UI | `lib/` | Renders the board, and is the only place that wires the other two together. |

### What happens when one player scores

```
   packages/engine        match_isolate        packages/leaderboard        lib/ui
   ┌──────────────┐     ┌────────────┐     ┌─────────────────┐      ┌─────────────┐
   │ score events │ ──▶ │ translate  │ ──▶ │ add to totals,  │ ───▶ │ leaderboard │
   │              │point│            │point│ re-rank, drop   │ranked│   screen    │
   │              │chnge│            │chnge│ no-op updates   │ board│             │
   └──────────────┘     └────────────┘     └─────────────────┘      └─────────────┘
        random           composition             domain                 widgets
      player + gap          root                  rules
   └────────────────── background isolate ──────────────────┘      └─ UI isolate ─┘
```

1. **The engine waits a random 500–2000 ms**, then picks a random player from the roster and
   announces that they gained some points. It announces a *change* — "+37" — never a total. It holds
   no scores at all, so there is nothing in it to get out of sync, nothing to reset, and no way for
   it to emit a decrease.
2. **The composition root translates that announcement** into the type the leaderboard accepts. This
   is the only place in the codebase that knows both sides exist.
3. **The leaderboard adds the points to that player's running total.** It is the sole owner of
   scores. A change naming a player who is not on the roster is discarded, so the board can never
   grow a row with no name behind it.
4. **The board is re-derived in ranked order** — sorted by score, ties sharing a rank, the next rank
   skipping past them.
5. **If the new ranking is identical to the last one, nothing is published.** Points can change
   without the board changing; when that happens the screen is never told, and so never rebuilds.
6. **The screen receives a finished board and renders it.** Each row is keyed by player rather than
   by position, so when two players swap places the framework understands it as *one row moving* and
   slides it, instead of as two rows whose contents both changed. That key is also what keeps the
   "score went up" highlight attached to the right player.

### Why the packages do not depend on each other

`packages/leaderboard` imports nothing from `packages/engine`. Instead it declares the input it is
willing to accept, and the composition root adapts the engine's output to it. That is deliberate: the
consumer owns the contract it consumes. The board can then be fed from a websocket, a replay file, or
a test fixture without editing either logic package — and in fact every leaderboard test feeds it by
hand, with the engine nowhere on the dependency graph.

Replacing the simulator with a real backend is one substitution in `_runMatch`. Nothing else in the
project moves, because nothing else knows the simulator exists.

### Threading

Generating events, accumulating totals and re-ranking the board all happen in a **background
isolate** (`lib/isolate/match_isolate.dart`). The UI isolate only ever receives a board that is
already sorted and ready, and paints it.

That matters because re-ranking is the one piece of work that grows with the number of players. Kept
off the UI isolate, its cost scales with the roster; run on the UI isolate, it would compete with the
frame budget, and a bigger roster would show up as dropped frames.

This is the one place where the Flutter and Kotlin versions differ in *shape* rather than in
vocabulary. Kotlin gets it from `Dispatchers.Default` — same memory, a different thread. Dart
isolates do not share memory, so the boards are **copied** across a port. At eight players that copy
is free and the isolate is arguably ceremony; the file says so in a `ponytail:` comment and names the
one-line path back to a UI-isolate `Timer` if the roster is never going to grow.

### Lifecycle

**On rotation**, the widget tree is rebuilt, but the board is not. Scores live in the isolate, below
the UI, so nothing is recomputed and nothing resets — the rebuilt screen picks up exactly the board
the old one was showing. Flutter never destroys the Dart state on a configuration change the way an
Android Activity is recreated, so this is free here; the Android version needed a ViewModel to get
it.

**In the background**, the match keeps running — like a tournament server, it does not pause because
one spectator looked away. What does stop, five seconds after the screen goes away, is the ranking
subscription, since there is nobody to show it to. Because totals live in the isolate rather than in
the stream feeding the UI, coming back costs a single board, not one for every event missed. A
ten-minute absence and a ten-second one cost the same.

**On process death**, everything is gone: scores are in memory only and the board restarts from zero.
A real backend would be the source of truth here and would restore it.

### Where ranking lives, and why

In the domain package, `packages/leaderboard`. Not in the UI, not in a provider — `rank()` is not
even *visible* to the app. It lives in `lib/src/ranking.dart` and is deliberately **not** exported
from `lib/leaderboard.dart`, which is Dart's equivalent of Kotlin's `internal`: the app sees the
finished board and nothing else, and reaching past the barrel file trips the `implementation_imports`
lint.

The payoff shows up in the tests: the entire ranking rule is exercised by handing a function a map of
player-to-score and checking the list that comes back. No streams, no fake clock, no widgets, no
Flutter.

The whole presentation layer is three providers in `lib/di/app_container.dart`. They rank nothing,
generate nothing and own nothing. That there is almost nothing in them is the package split working,
not an oversight.

### Ranking rules

Competition ("1224") ranking — sorted by score descending, players on the same score share a rank,
and the next rank skips past the whole tie group. Four players on 500 / 300 / 300 / 100 rank
1, 2, 2, 4.

Players on equal scores are then ordered by id, and that detail is the actual fix for flicker.
Ordered by score alone, two players tied on 300 have no defined order relative to each other, so the
same set of scores can produce a differently ordered board each time it is computed and the two rows
swap places forever while nothing is actually happening. With the tie-break the board is a pure
function of the scores — the same scores always produce the exact same board — which is what makes it
possible to detect that nothing changed and skip the update entirely.

## Why Flutter draws it this way

- **Rank-movement animation is a keyed `AnimatedPositioned`.** Rows are laid out in a `Stack` at
  `index * rowStep` with `ValueKey(playerId)`. When the index changes, the framework matches the
  element by key and slides it. Flutter has no direct equivalent of Compose's `Modifier.animateItem()`
  — `AnimatedList` handles inserts and removals, not reorders — so the position is made explicit and
  animated implicitly. Cost: a `Stack` lays every row out at once and does not virtualise, which is
  noted in the file.
- **Phase control.** The leader's score is passed to each row as a `ValueListenable<int>` rather than
  an `int` (`lib/ui/leaderboard_row.dart`), and the row's `CustomPainter` takes it as `repaint:`.
  When the leader scores, every row's bar repaints and **not one row rebuilds**. This is Flutter's
  answer to Compose passing `State<Long>` down and reading it in `drawBehind`: "this value changed,
  repaint but do not rebuild".
- **The pulse is an `AnimationController` read inside the painter and by a `FadeTransition`**, so a
  900 ms animation on eight rows costs zero widget rebuilds.
- **Tabular figures via `FontFeature.tabularFigures()`** rather than a monospace family. The Compose
  version reaches for `FontFamily.Monospace` to get fixed-advance digits; Flutter can ask the same
  typeface for them directly, so the score column stops jittering without changing the type.

None of that is polish — the brief cares about correctness and performance under live updates, and
these are the levers that keep a board updating every 500–2000 ms off the UI isolate and out of the
widget tree.

## Android → Flutter

The mapping in full. The top block is what this app actually uses; the bottom block is what the rest
of a typical Android stack maps to, so the table is complete even though the code is not padded out
with dependencies it has no work for.

### Build and structure

| Android | Flutter | Here |
|---|---|---|
| Gradle `java-library` module | pure Dart package (no `flutter` dependency → `import 'package:flutter/…'` is a compile error) | `packages/engine`, `packages/leaderboard` |
| Gradle `com.android.application` module | the root Flutter package | `lib/` |
| `settings.gradle.kts` include | `path:` dependency in `pubspec.yaml` | ✅ |
| `gradle/libs.versions.toml` | `pubspec.yaml` + `pubspec.lock` | ✅ |
| Gradle wrapper (pinned Gradle) | pinned Flutter SDK (`environment.sdk`, or `fvm`) | ✅ |
| `internal` visibility | unexported `lib/src/…` + `implementation_imports` lint | `rank()` |
| `data class` | class + `package:equatable` (or `freezed`, with codegen) | all four models |
| `require(...)` in `init` | `throw ArgumentError` in the constructor body | ✅ |
| ProGuard / R8 | tree shaking, automatic in release | — |
| `productFlavors` | the same Gradle `productFlavors`, selected with `flutter run --flavor` (plus an Xcode scheme per flavor on iOS) | `android/app/build.gradle.kts` — **Android only here**; iOS has no schemes |
| `BuildConfig.FLAVOR` read in Kotlin | `--dart-define` read via `String.fromEnvironment` | — nothing in `lib/` reads the flavor |

### Wiring and state

| Android | Flutter | Here |
|---|---|---|
| Hilt / Koin / Dagger | **Riverpod** | `lib/di/app_container.dart` |
| `object AppContainer` composition root | a file of top-level providers | ✅ |
| `ViewModel` + `viewModelScope` | a provider + `ref.onDispose` | `rankingsProvider` |
| `Flow<T>` | `Stream<T>` | ✅ |
| `StateFlow<T>` / `MutableStateFlow<T>` | `ValueListenable<T>` / `ValueNotifier<T>` | `_topScore` |
| `stateIn(scope, WhileSubscribed(5_000), …)` | `StreamProvider.autoDispose` + `ref.keepAlive()` + a 5 s `Timer` in `onCancel` | `rankingsProvider` |
| `collectAsStateWithLifecycle()` | `ref.watch(provider)` in a `ConsumerWidget` | ✅ |
| `distinctUntilChanged()` | `Stream.distinct(equals)` | `LeaderboardEngine.rankings` |
| `flow { }` cold builder | `async*` generator | `SimulatedScoreEngine.events` |
| `suspend fun` | `Future` / `async`-`await` | `consume()` |
| `delay(ms)` | `Future.delayed(Duration(...))` | ✅ |
| `Dispatchers.Default` | `Isolate.spawn` (or `compute` for one-shot work) | `lib/isolate/` |
| `CoroutineScope(SupervisorJob())`, never cancelled | a non-`autoDispose` provider holding the isolate | `matchProvider` |
| `scope.cancel()` | `Isolate.kill()` / `StreamSubscription.cancel()` | `Match.stop()` |

### UI

| Compose | Flutter | Here |
|---|---|---|
| `@Composable fun` | `Widget` subclass | ✅ |
| `Activity` + `setContent` | `runApp` + `MaterialApp` | `lib/main.dart` |
| `MaterialTheme` / `darkColorScheme` | `ThemeData` / `ColorScheme.dark` | `lib/theme/` |
| `Scaffold` | `Scaffold` | ✅ |
| `Column` / `Row` / `Box` | `Column` / `Row` / `Stack` | ✅ |
| `Modifier.padding` / `.size` / `.weight` | `Padding` / `SizedBox` / `Expanded` | ✅ |
| `LazyColumn` + `items(key = …)` | `ListView.builder` with `ValueKey` (here: `Stack` + `AnimatedPositioned`) | ✅ |
| `Modifier.animateItem()` | keyed `AnimatedPositioned` | ✅ |
| `Modifier.drawBehind { }` / `Canvas` | `CustomPaint` + `CustomPainter` | row card, logo |
| `State<T>` read in `drawBehind` (draw-phase invalidation) | `CustomPainter(repaint: Listenable)` | `topScore` |
| `Animatable` + `snapTo`/`animateTo` | `AnimationController` + `forward(from: 0)` | the pulse |
| `rememberInfiniteTransition` | `AnimationController.repeat(reverse: true)` | LIVE badge |
| `Modifier.graphicsLayer { alpha = … }` | `FadeTransition` | gain chip |
| `remember { }` | `State` field on a `StatefulWidget` | `_previous` |
| `derivedStateOf { }` | a computed value in `build`, or `provider.select` | `totalPoints` |
| `LaunchedEffect(key)` | `didUpdateWidget` / `initState` | pulse trigger |
| `enableEdgeToEdge()` | `SystemChrome.setEnabledSystemUIMode(edgeToEdge)` + `SystemUiOverlayStyle` | `main.dart` |
| `WindowInsets` / `calculateStartPadding` | `SafeArea` (direction-aware) / `MediaQuery.padding` | ✅ |
| `semantics { contentDescription = … }` | `Semantics(label: …)` | row |
| `@Preview` | a widget test, or the DevTools widget inspector | `LeaderboardBoard` |
| adaptive icon XML + `mipmap-*` | `flutter_launcher_icons` (Android **and** iOS in one config) | `pubspec.yaml` |
| per-flavor `src/<flavor>/res/` overlay | same thing — `flutter_launcher_icons-<flavor>.yaml` writes into it | `dev`, `staging` |
| `windowBackground` theme to avoid a white flash | `flutter_native_splash` | `pubspec.yaml` |
| `AndroidManifest.xml` | `AndroidManifest.xml` **and** `ios/Runner/Info.plist` | two platforms now |

### Tooling

| Android | Flutter | Here |
|---|---|---|
| ktlint / Spotless | `dart format` | ✅ |
| detekt | `flutter analyze` + a strict lint set | `very_good_analysis` |
| Android Lint | `flutter analyze` (same command) | ✅ |
| JUnit | `package:test` | logic packages |
| Robolectric / Espresso | `flutter_test` (`testWidgets`) — in-process, no emulator | `test/` |
| `kotlinx-coroutines-test` virtual time | `package:fake_async` | engine tests |
| Turbine | `expectLater(stream, emitsInOrder([...]))` | — |
| MockK / Mockito | `package:mocktail` | not needed; no collaborators to fake |
| `./gradlew assembleDebug` | `flutter build apk` | ✅ |
| `./gradlew installDebug` | `flutter run` | ✅ |

### Not used here — where they would plug in

| Android | Flutter | Would go |
|---|---|---|
| **Retrofit + OkHttp** | **`dio` + `retrofit` (Dart), or `chopper`** | a `ScoreEngine` implementation replacing `SimulatedScoreEngine` |
| Ktor client / WebSocket | `web_socket_channel` | same place — that is the swap point |
| Moshi / Gson / kotlinx-serialization | `json_serializable` + `dart:convert` | DTOs alongside the network engine |
| Room | `drift` | a `LeaderboardEngine` that restores totals on launch |
| DataStore / SharedPreferences | `shared_preferences` | — |
| Coil / Glide | `cached_network_image` | player avatars, if they ever became images |
| Navigation-Compose | `go_router` | — one screen, nothing to route |
| Paging 3 | `infinite_scroll_pagination` | a roster too large to hold in memory |
| WorkManager | `workmanager` | — |
| Firebase / Crashlytics / Analytics | `firebase_core`, `firebase_crashlytics`, `firebase_analytics` | — |
| `LocalBroadcastManager` / `EventBus` | `Stream` — already the primitive | ✅ |
| JNI / NDK | `dart:ffi`, or platform channels | — |

## Flavors

Three Android build flavors, so dev, staging and production install side by side on one device and
are distinguishable on the launcher.

| Flavor | applicationId | Launcher label | Icon |
|---|---|---|---|
| `dev` | `com.scoreline.app.dev` | Scoreline Dev | gold → green |
| `staging` | `com.scoreline.app.stg` | Scoreline Staging | bronze → violet |
| `prod` | `com.scoreline.app` | Scoreline | violet → cyan |

`prod` deliberately carries **no** `applicationIdSuffix`, so the shipping id stays
`com.scoreline.app` and an already-installed build upgrades in place rather than becoming a fourth
app on the device.

The icon colours are `gold`, `gain`, `bronze` and `violet` from `lib/theme/arena_theme.dart` — the
same palette the board uses, so the three read as one app in three builds rather than as three apps.
The white bolt is identical in all three; only the background differs. `tool/generate_icons.py`
emits one badge per flavor from the same geometry `lib/ui/scoreline_logo.dart` draws.

### `--flavor` is not optional on Android

Once `productFlavors` exist, Gradle has no default variant, so a bare `flutter run` or
`flutter build apk` **fails**. Every Android command takes a flavor from here on. That is inherent to
Android flavors, not a choice this project made.

The failure is worth knowing verbatim, because the message does not mention flavors at all:

```
Error: Gradle build failed to produce an .apk file. It's likely that this file was
generated under .../build, but the tool couldn't find it.
```

Gradle actually succeeded — it built `assembleDebug`, which produces nothing, because every real
variant is now `assembleDevDebug` / `assembleStagingDebug` / `assembleProdDebug`. If you see that
message, you forgot `--flavor`.

`flutter test`, `flutter analyze` and `dart format` are unaffected — they never invoke Gradle.

### What varies, and what does not

Identity only: **applicationId, launcher label, launcher icon.** Nothing behavioural is switched, and
**nothing in `lib/` reads the flavor** — there is no flavor config class, no `--dart-define`, no
on-screen flavor badge, and the match engine runs with the same seed and the same 500–2000 ms
interval in all three.

That is deliberate. A flavor that changes behaviour is a flavor whose behaviour is untested in the
other two. When one of these does need to point at a different backend, the honest place for it is a
`--dart-define` read at the composition root (`lib/di/app_container.dart`), not a Gradle field the
Dart side cannot see. The mapping table records that route.

### iOS has no flavors

`flutter run --flavor dev` **fails on iOS** — Flutter maps `--flavor` to an Xcode scheme, and only the
default `Runner` scheme exists. iOS builds and runs with a plain `flutter run` / `flutter build ios`,
which is what the Commands table shows.

Closing this properly means adding three schemes and three build configurations per build type — nine
configurations — in `ios/Runner.xcodeproj/project.pbxproj`. That is real work and was explicitly out
of scope; it is written down here rather than left to be discovered at the wrong moment.

### One AGP 9 wrinkle

`android/app/build.gradle.kts` sets `buildFeatures { resValues = true }`. AGP 9 turns generated
resource values off by default, and the flavors declare `app_name` through `resValue`; without the
flag the build fails at configuration time with "contains custom resource values, but the feature is
disabled". The alternative is a `strings.xml` per flavor source set — three files instead of one
line, and it splits each flavor's identity away from where the flavor is declared.

## Commands

| Command | What it does |
|---|---|
| `flutter analyze` | Static analysis under `very_good_analysis`, across the app and both packages. |
| `dart format --set-exit-if-changed .` | Fails if any file is misformatted. `dart format .` fixes it. |
| `flutter test` | Widget tests and the match regression test. |
| `cd packages/leaderboard && dart test` | 20 domain tests on the plain Dart VM. |
| `cd packages/engine && dart test` | 8 engine tests on the plain Dart VM. |
| `flutter run --flavor dev` | Builds and installs on a connected Android device or emulator. **The flavor is not optional on Android** — see [Flavors](#flavors). |
| `flutter run` | Same, on iOS. iOS has no flavors here, so it takes no `--flavor`. |
| `flutter build apk --flavor prod` | Android APK. `--debug` for an unsigned local build. |
| `flutter build appbundle --flavor prod` | Android App Bundle, for Play. |
| `flutter build ipa` | iOS archive. Needs Xcode and a signing identity. |
| `python3 tool/generate_icons.py` | Regenerates the icon sources — one badge per flavor — from the same geometry the header logo draws. |
| `dart run flutter_launcher_icons` | Regenerates the **flavor** icons. Picks up every `flutter_launcher_icons-*.yaml` and writes each into `android/app/src/<flavor>/res/`. Once those files exist it ignores the `flutter_launcher_icons:` block in `pubspec.yaml`. |
| `dart run flutter_launcher_icons -f pubspec.yaml` | Regenerates the **prod and iOS** icons from that block. Needed because the command above skips it. |
| `dart run flutter_native_splash:create` | Regenerates the dark launch background on both platforms. |

The two logic packages are tested with `dart test`, not `flutter test`, and that is the point: they
have no Flutter dependency, so they run on the plain Dart VM in milliseconds. It is the same benefit
the Android version gets from `./gradlew :leaderboard:test` needing no emulator and no Robolectric.

## Requirements

| | Needed | This repo |
|---|---|---|
| Flutter | 3.35 or newer | built and tested on 3.47.1 (stable) |
| Dart | 3.13 or newer | 3.13.1, declared in `environment.sdk` |
| Android | compileSdk 36, minSdk 24 | Flutter's defaults; APK builds clean |
| iOS | 13.0 or newer | Flutter's default deployment target |
| Xcode | 15+ for iOS builds | built and run on 26.4.1, iOS 26.4 simulator |
| CocoaPods | only if a plugin ships native code | **not needed** — `.flutter-plugins-dependencies` lists `"ios":[]`, so there is no `Podfile` and Flutter skips the pod step |

`flutter doctor` is the equivalent of checking your Android Studio and SDK versions before opening
the Gradle project.

## Tech stack

| | | Version |
|---|---|---|
| **Language & build** | Dart | 3.13.1 |
| | Flutter | 3.47.1 |
| **State & DI** | flutter_riverpod | ^3.0.3 |
| **Models** | equatable | ^2.0.7 |
| **Async** | `dart:async` (`Stream`, `Future`) | SDK |
| **Concurrency** | `dart:isolate` | SDK |
| **Testing** | test | ^1.25.8 |
| | flutter_test | SDK |
| | fake_async | ^1.3.2 |
| **Quality** | very_good_analysis | ^7.0.0 |
| | `dart format` | SDK |
| **Packaging** | flutter_launcher_icons | ^0.14.4 |
| | flutter_native_splash | ^2.4.6 |

Two things are deliberately *not* in the stack:

- **No networking or persistence library.** There is no backend and nothing to persist. A `dio`
  client added now would be a dependency with no traffic; the table above records where it goes when
  there is.
- **No code generation.** `build_runner`, `freezed` and `riverpod_generator` are all reasonable at
  scale, and all of them buy a build step to save boilerplate this app does not have. Four models
  extending `Equatable` and three hand-written providers are shorter than the generator config.

## Trade-offs

- **The engine emits deltas, not absolute scores.** "A score only increases" becomes a property of
  the type — a positive `int` added to a running total cannot decrease it — instead of a rule every
  caller has to remember. The engine therefore holds no score state, needs no synchronisation and has
  no reset path.
- **Score state lives in `LeaderboardEngine`, not in the stream.** A `fold` over the delta stream
  would be shorter and wrong: the accumulator resets every time the last listener goes away, so the
  board would zero itself on every return from background. Keeping it outside is what makes
  resubscription free and lets the UI drop its listener without consequence. There is a regression
  test for this in `test/match_test.dart`.
- **The snapshot is taken at mutation time, not at delivery time.** A buffered change event that
  reads the score map late sees later mutations too, silently collapsing two boards into one. This
  cost one test failure to find and is the kind of thing `StateFlow` hides on the Kotlin side.
- **`Match` is process-lifetime and never stopped.** The match keeps running while the user is
  elsewhere, like a tournament server would. The isolate captures a roster of two-string values and
  an int seed — no `BuildContext`, no widget — so "never stopped" means "dies with the process", not
  "leaks".
- **`Match` holds the last board in the UI isolate.** The isolate owns the totals, but a screen
  coming back needs standings *now*, not in up to two seconds. One cached list bridges that; it is
  null until the first real board arrives, because publishing an empty board is publishing standings
  that are wrong rather than merely absent.
- **JVM string hashing is reimplemented for the avatar hue.** Dart's `String.hashCode` is a different,
  deliberately unspecified function, so using it would have given the Flutter build different avatar
  colours than the Android one. `lib/ui/leaderboard_row.dart` carries Java's `31 * h + c` and uses
  `remainder` rather than `%`, because Dart's `%` is always non-negative where Kotlin's keeps the
  sign.
- **Dark-only theme.** A light variant means a second set of accent colours tuned for contrast on
  white. That is a real design surface, and nobody asked for it on a one-screen game.
- **A `Stack` of `AnimatedPositioned` rather than a `ListView`.** It buys the rank-swap slide with
  no dependency, and costs virtualisation. Correct for a roster that fits on screen and marked as the
  ceiling it is.

## What I'd improve with more time

- **`rank()` re-sorts the whole roster on every event**, O(n log n), and allocates a fresh
  `List<LeaderboardEntry>` per event. Nothing at ~1K players and ~2 events/sec, but the sustained
  allocation is the real ceiling for a screen showing fifteen rows — and here every board is also
  *copied* across the isolate port, which doubles it. The upgrade is a windowed query on
  `LeaderboardEngine` (`window(range)` + `rankOf(playerId)`) over a score-bucketed index: a
  `packages/leaderboard` change with the app untouched.
- **The header's "points in play" total sums the whole roster on the UI isolate.** Irrelevant at eight
  players; it belongs in the isolate alongside the ranked output before it is a 100K-player board.
- **A delta outside the engine's contract would throw inside `_runMatch`** and kill the background
  isolate with no signal to the UI, freezing the board. Unreachable today because
  `SimulatedScoreEngine` validates its ranges at construction, but a real network source would want
  the isolate to catch it and post an error state across the port.
- **The board does not virtualise.** See the trade-off above; the fix is a keyed `ListView` plus an
  explicit rank-change animation, and it is worth doing the moment the roster stops fitting on screen.
- **Swapping in a real backend** means one line: `_runMatch` builds a different `ScoreEngine`. Nothing
  else moves.

## Project layout

```
scoreline/
├── packages/
│   ├── engine/                    ≡ :engine — pure Dart
│   │   ├── lib/src/score_engine.dart          Player, ScoreEvent, ScoreEngine
│   │   └── lib/src/simulated_score_engine.dart
│   └── leaderboard/               ≡ :leaderboard — pure Dart, no dep on engine
│       ├── lib/leaderboard.dart               barrel; rank() deliberately absent
│       └── lib/src/{ranking,leaderboard_engine,score_delta,leaderboard_entry}.dart
├── lib/
│   ├── main.dart                  ≡ MainActivity
│   ├── di/app_container.dart      ≡ AppContainer — the Riverpod graph
│   ├── isolate/match_isolate.dart ≡ Dispatchers.Default + the ScoreEvent→ScoreDelta map
│   ├── theme/arena_theme.dart     ≡ ArenaTheme
│   └── ui/{leaderboard_screen,leaderboard_header,leaderboard_row,scoreline_logo}.dart
├── test/                          widget tests + the match regression test
├── tool/generate_icons.py         icon sources, one badge per flavor
├── flutter_launcher_icons-dev.yaml, -staging.yaml
│                                  per-flavor icons; prod inherits main/
├── android/                       three flavors — see Flavors
│   └── app/src/{main,dev,staging}/res/        flavor res overlays main
├── ios/                           single Runner scheme; no flavors
└── assets/icon/                   generated icon sources
```
