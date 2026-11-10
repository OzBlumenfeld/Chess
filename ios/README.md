# Chess Analyzer (iOS)

An iPhone app: enter a chess.com nickname, browse their latest games, step
through a game on a board, and see which opening each player chose. It talks
to chess.com's public API directly, so it needs no server.

- `ChessCore/`: the chess.com client, PGN replay and opening names. Plain
  Swift with no UI and no dependencies, so it tests on the Mac.
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

## App icon

`ChessAnalyzer/Assets.xcassets/AppIcon.appiconset/AppIcon.png` is a single
1024×1024 image; Xcode makes the other sizes. `Design/AppIcon/` holds the
alternatives (`preview.png` shows all three) and their SVG sources. To switch,
copy another PNG over `AppIcon.png`.
