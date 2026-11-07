# Scoreline

A real-time leaderboard app built with Flutter for Android and iOS. A simulated match sends score
updates every few seconds, and the board re-ranks itself live with smooth row animations.

## Features

- Live leaderboard that updates every 0.5–2 seconds
- Animated rank changes: rows slide to their new position
- Tied players share a rank (500 / 300 / 300 / 100 → 1, 2, 2, 4)
- Score logic runs in a background isolate, so the UI stays smooth
- Android build flavors: `dev`, `staging`, `prod`

## Tech stack

- Flutter and Dart
- Riverpod for state management and dependency injection
- Dart isolates for background work
- `flutter_test` and `package:test` for testing
- `very_good_analysis` for linting

## Project structure

```
lib/                     Flutter app: UI, theme, providers
  di/                    Riverpod providers
  isolate/               background isolate that runs the match
  ui/                    screens and widgets
packages/engine/         pure Dart: generates score events
packages/leaderboard/    pure Dart: adds up scores and ranks players
```

The two packages under `packages/` don't depend on Flutter, so the core logic is simple to test and
reuse.

## Run

```bash
flutter pub get
flutter run --flavor dev    # Android
flutter run                 # iOS
```

## Test

```bash
flutter test
cd packages/leaderboard && dart test
cd packages/engine && dart test
```
