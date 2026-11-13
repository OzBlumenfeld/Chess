# Chess Analyzer (iOS)

An iPhone app: enter a chess.com nickname, browse their latest games, step
through a game on a board, and see which opening each player chose. It talks
to chess.com's public API directly, so it needs no server.

An Openings tab teaches 20 common openings: pick one, choose a variation, and
step through it (or press play) on the board.

- `ChessCore/`: the chess.com client, PGN replay, opening names and the
  openings library (`OpeningLibrary.swift`). Plain Swift with no UI and no
  dependencies, so it tests on the Mac.
- `ChessAnalyzer/`: the SwiftUI app.
- `ChessAnalyzerUITests/`: drives the app against live chess.com.

## Build

The Xcode project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) and is not committed.

```bash
cd ios
xcodegen generate
open ChessAnalyzer.xcodeproj
```

Then set your Team under Signing & Capabilities and run. Regenerating resets
the Team.

## Test

```bash
cd ios/ChessCore && swift test
```

The UI tests run from Xcode (⌘U) or with `xcodebuild test` on a simulator.
