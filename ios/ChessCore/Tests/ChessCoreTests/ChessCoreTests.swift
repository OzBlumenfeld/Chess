import Foundation
import Testing

@testable import ChessCore

private func fixture(_ name: String) throws -> Data {
  let url = try #require(
    Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
  return try Data(contentsOf: url)
}

private struct GameList: Decodable { let games: [ChessGame] }

private func fixtureGames() throws -> [ChessGame] {
  try ["archive_older", "archive_recent"].flatMap {
    try JSONDecoder().decode(GameList.self, from: fixture($0)).games
  }
}

private actor Counter {
  var urls: [String] = []
  func add(_ url: String) { urls.append(url) }
}

private let oldURL = "https://api.chess.com/pub/player/hikaru/games/2026/10"
private let newURL = "https://api.chess.com/pub/player/hikaru/games/2026/11"
private let archives = Data(#"{"archives":["\#(oldURL)","\#(newURL)"]}"#.utf8)

@Suite struct ClientTests {
  @Test func walksBackAcrossMonthsNewestFirst() async throws {
    let recent = try fixture("archive_recent")
    let older = try fixture("archive_older")
    let client = ChessComClient { url in
      switch url.absoluteString {
      case newURL: (recent, 200)
      case oldURL: (older, 200)
      default: (archives, 200)
      }
    }
    let games = try await client.recentGames(for: " Hikaru ")
    #expect(games.count == 5)  // 3 from the new month, 2 from the old one
    #expect(games.map(\.endTime) == games.map(\.endTime).sorted(by: >))
  }

  @Test func pagesThroughHistoryWithoutRefetching() async throws {
    let recent = try fixture("archive_recent")
    let older = try fixture("archive_older")
    let fetched = Counter()
    let client = ChessComClient { url in
      await fetched.add(url.absoluteString)
      switch url.absoluteString {
      case newURL: return (recent, 200)
      case oldURL: return (older, 200)
      default: return (archives, 200)
      }
    }
    let first = try await client.firstPage(for: "hikaru")
    #expect(first.games.count == 5 && first.cursor.hasMore)

    let second = try await client.nextPage(after: first.cursor)
    #expect(second.games.count == 2)  // 7 fixture games in all
    #expect(!second.cursor.hasMore)
    #expect(Set(first.games.map(\.id)).isDisjoint(with: second.games.map(\.id)))
    let all = (first.games + second.games).map(\.endTime)
    #expect(all == all.sorted(by: >))
    #expect(await fetched.urls.count == 3, "archive list and each month fetched once")

    let third = try await client.nextPage(after: second.cursor)
    #expect(third.games.isEmpty)
  }

  @Test func skipsVariants() async throws {
    let body = String(decoding: try fixture("archive_recent"), as: UTF8.self)
      .replacingOccurrences(of: #""rules": "chess""#, with: #""rules": "chess960""#)
    let client = ChessComClient { url in
      url.absoluteString.hasSuffix("archives") ? (archives, 200) : (Data(body.utf8), 200)
    }
    #expect(try await client.recentGames(for: "hikaru").isEmpty)
  }

  @Test func skipsListedMonthThatReturns404() async throws {
    let older = try fixture("archive_older")
    let client = ChessComClient { url in
      switch url.absoluteString {
      case newURL: (Data(), 404)
      case oldURL: (older, 200)
      default: (archives, 200)
      }
    }
    #expect(try await client.recentGames(for: "hikaru").count == 4)
  }

  @Test func unknownPlayerIsTyped() async {
    let client = ChessComClient { _ in (Data(), 404) }
    await #expect(throws: ChessComError.playerNotFound("nobody")) {
      try await client.recentGames(for: "Nobody")
    }
  }

  @Test func serverErrorIsTyped() async {
    let client = ChessComClient { _ in (Data(), 429) }
    await #expect(throws: ChessComError.badStatus(429)) {
      try await client.recentGames(for: "hikaru")
    }
  }
}

@Suite struct OpeningTests {
  @Test(arguments: [
    ("Sicilian-Defense-Canal-Attack...4.Ba4-Nf6-5.O-O-a6-6.c4", "Sicilian Defense Canal Attack"),
    ("Scotch-Game-Scotch-Gambit-4.Bc4", "Scotch Game Scotch Gambit"),
    ("Queens-Pawn-Opening-1...d5", "Queens Pawn Opening"),
    ("Caro-Kann-Defense", "Caro Kann Defense"),
    (
      "Caro-Kann-Defense-Advance-Short-Variation-with-4-Nf3...e6-5.Be2",
      "Caro Kann Defense Advance Short Variation"
    ),
  ])
  func namesFromSlugs(slug: String, name: String) {
    #expect(OpeningParser.name(fromURL: "https://www.chess.com/openings/\(slug)") == name)
  }

  @Test func rejectsNonOpeningURLs() {
    #expect(OpeningParser.name(fromURL: "https://www.chess.com/game/live/1") == nil)
    #expect(OpeningParser.name(fromURL: "https://www.chess.com/openings/Undefined") == nil)
  }

  @Test func creditsDefensesToBlack() {
    #expect(OpeningParser.chooser(of: "Sicilian Defense") == .black)
    #expect(OpeningParser.chooser(of: "Albin Countergambit") == .black)
    #expect(OpeningParser.chooser(of: "Italian Game") == .white)
  }
}

@Suite struct ReplayTests {
  @Test func everyFixtureEndsOnChessComsPosition() throws {
    for game in try fixtureGames() {
      let replay = try GameReplay(pgn: game.pgn)
      let expected = try #require(game.pgnTag("CurrentPosition"))
      #expect(replay.fens.last == expected, "\(game.url)")
      #expect(replay.positions.count == replay.plies.count + 1)
      #expect(replay.positions[0].count == 32)
    }
  }

  @Test func readsMovesAndClocks() throws {
    let game = try #require(try fixtureGames().last)
    let replay = try GameReplay(pgn: game.pgn)
    #expect(replay.plies[0].san == "e4")
    #expect(replay.plies[0].isWhite && replay.plies[0].moveNumber == 1)
    #expect(replay.plies[1].san == "c5")
    #expect(!replay.plies[1].isWhite)
    #expect(replay.plies[0].clock == "0:03:00")
    #expect(replay.plies[0].to == BoardSquare(file: 4, rank: 3))
  }

  @Test func rejectsGarbage() {
    #expect(throws: GameReplayError.self) { try GameReplay(pgn: "not a pgn at all [[[") }
  }

  @Test func gameAbandonedBeforeFirstMoveHasNoPlies() throws {
    let replay = try GameReplay(pgn: "[White \"a\"]\n[Link \"https://x\"]\n\n0-1\n")
    #expect(replay.plies.isEmpty)
    #expect(replay.positions.count == 1)
  }

  @Test func rejectsMoveThatCantBePlayed() {
    #expect(throws: GameReplayError.unresolvedMove("Ke4")) {
      try GameReplay(pgn: "1. e4 e5 2. Ke4 *")
    }
  }

  @Test(arguments: [
    // Disambiguated captures, which is where ChessKit moved the wrong knight.
    ("4k3/8/8/3p4/5N2/2N5/8/4K3 w - - 0 1", "1. Nfxd5", "4k3/8/8/3N4/8/2N5/8/4K3 b - - 0 1"),
    // Both knights reach b5, but c3 is pinned, so SAN needs no qualifier.
    ("4k3/8/8/8/1b6/N1N5/8/4K3 w - - 0 1", "1. Nb5", "4k3/8/8/1N6/1b6/2N5/8/4K3 b - - 1 1"),
    // Castling moves the rook and clears that side's rights.
    ("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", "1. O-O", "r3k2r/8/8/8/8/8/8/R4RK1 b kq - 1 1"),
    ("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", "1. O-O-O", "r3k2r/8/8/8/8/8/8/2KR3R b kq - 1 1"),
    // Capturing a rook removes its owner's rights too.
    ("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", "1. Rxa8+", "R3k2r/8/8/8/8/8/8/4K2R b Kk - 0 1"),
    // Promotions, with and without a capture.
    ("8/P6k/8/8/8/8/8/K7 w - - 0 1", "1. a8=Q+", "Q7/7k/8/8/8/8/8/K7 b - - 0 1"),
    ("1n6/P6k/8/8/8/8/8/K7 w - - 0 1", "1. axb8=N", "1N6/7k/8/8/8/8/8/K7 b - - 0 1"),
  ])
  func specialMoves(start: String, moves: String, end: String) throws {
    let replay = try GameReplay(pgn: "[FEN \"\(start)\"]\n\n\(moves) *")
    #expect(replay.fens.last == end)
  }

  @Test func enPassantRemovesTheCapturedPawn() throws {
    let replay = try GameReplay(pgn: "1. e4 a6 2. e5 d5 3. exd6 *")
    #expect(replay.fens.last == "rnbqkbnr/1pp1pppp/p2P4/8/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 3")
  }
}

@Suite struct GameTests {
  @Test func outcomeIsFromTheNamedPlayersSide() throws {
    let game = try #require(try fixtureGames().last)  // Hikaru won as Black
    #expect(game.outcome(for: "hikaru") == .win)
    #expect(game.outcome(for: "only_strong_moves") == .loss)
    #expect(!game.isWhite("HIKARU"))
    #expect(game.pgnTag("ECO") == "B51")
  }

  @Test func summaryCreditsTheRightSide() throws {
    let game = try #require(try fixtureGames().last)
    let replay = try GameReplay(pgn: game.pgn)
    let summary = OpeningParser.summary(of: game, sans: replay.plies.map(\.san))
    #expect(summary.name == "Sicilian Defense Canal Attack")
    #expect(summary.blackChoice == summary.name && summary.whiteChoice == nil)
    #expect(summary.whiteFirstMove == "e4" && summary.blackFirstMove == "c5")
  }
}

@Suite struct OpeningLibraryTests {
  @Test func everyLineReplaysAndStartsWithItsOpening() throws {
    for opening in OpeningLibrary.all {
      let base = try GameReplay(pgn: opening.moves).plies.map(\.san)
      #expect(!base.isEmpty, "\(opening.name)")
      #expect(!opening.variations.isEmpty, "\(opening.name)")
      for variation in opening.variations {
        let line = try GameReplay(pgn: variation.moves).plies.map(\.san)
        #expect(Array(line.prefix(base.count)) == base, "\(variation.name)")
        #expect(line.count > base.count, "\(variation.name)")
      }
    }
  }

  @Test func namesAreUnique() {
    let names = OpeningLibrary.all.map(\.name)
    #expect(Set(names).count == names.count)
    for opening in OpeningLibrary.all {
      let variations = opening.variations.map(\.name)
      #expect(Set(variations).count == variations.count, "\(opening.name)")
    }
  }

  @Test func everyFamilyHasOpenings() {
    for family in Opening.Family.allCases {
      #expect(!OpeningLibrary.openings(in: family).isEmpty)
    }
  }
}
