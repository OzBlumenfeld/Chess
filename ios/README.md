# Chess Analyzer (iOS)

An iPhone app: pick Chess.com or Lichess, enter a username, browse their
latest games, step through a game on a board, and see which opening each
player chose. It talks to both sites' public APIs directly, so it needs no
server or login.

On a game's Board tab, **Review game** runs Stockfish 17 on the phone over
every position: moves get ?!/?/?? marks, the board shows an eval bar and the
engine's best move as an arrow, and a Review tab shows each player's accuracy,
mistake counts, an evaluation graph and the key moments (tap to jump there).
Labels use the same centipawn-loss thresholds as `analyze_games.py`; accuracy
uses Lichess's win-chance formula.

An Openings tab teaches 20 common openings: pick one, choose a variation, and
step through it (or press play) on the board.

- `ChessCore/`: the chess.com and Lichess clients (`GameFetcher` picks one), PGN replay, opening names and the
  openings library (`OpeningLibrary.swift`). Plain Swift with no UI and no
  dependencies, so it tests on the Mac.
- `ChessAnalyzer/`: the SwiftUI app. `StockfishEngine.swift` wraps the engine;
  the review math (labels, accuracy, UCI to SAN) is in `ChessCore/GameReview.swift`.
- `ChessAnalyzerUITests/`: drives the app against live chess.com.

## Build

The Xcode project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) and is not committed.

```bash
cd ios
scripts/fetch-nnue.sh   # Stockfish's networks (~78 MB), kept out of git
xcodegen generate
open ChessAnalyzer.xcodeproj
```

Then set your Team under Signing & Capabilities and run. The scheme runs the
Release configuration: Xcode builds Swift packages unoptimized in Debug, which
makes Stockfish more than 10× slower.

Stockfish comes from [ChessKitEngine](https://github.com/chesskit-app/chesskit-engine)
and is GPL v3, so a build you distribute must ship under the GPL too. Regenerating resets
the Team.

## Test

```bash
cd ios/ChessCore && swift test
```

The UI tests run from Xcode (⌘U) or with `xcodebuild test` on a simulator.
