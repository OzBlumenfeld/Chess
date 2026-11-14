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

private func uci(_ ply: Ply) -> String {
  func name(_ square: BoardSquare) -> String {
    "\(Character(UnicodeScalar(UInt8(97 + square.file))))\(square.rank + 1)"
  }
  let promotion = ply.san.split(separator: "=").dropFirst().first?.prefix(1).lowercased() ?? ""
  return name(ply.from) + name(ply.to) + promotion
}

@Suite struct ReviewTests {
  @Test func uciToSANMatchesEveryFixtureMove() throws {
    for game in try fixtureGames() {
      let replay = try GameReplay(pgn: game.pgn)
      for ply in replay.plies {
        let expected = ply.san.replacingOccurrences(of: "#", with: "+")
        #expect(replay.san(ofUCI: uci(ply), atPosition: ply.id - 1) == expected, "\(game.url)")
      }
    }
  }

  @Test(arguments: [
    ("4k3/8/8/3p4/5N2/2N5/8/4K3 w - - 0 1", "f4d5", "Nfxd5"),
    ("4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1", "e1c1", "O-O-O"),
    ("8/4P3/8/8/8/8/k7/4K3 w - - 0 1", "e7e8q", "e8=Q"),
    ("4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1", "a1a8", "Ra8+"),
    ("3k4/8/8/8/8/8/4K3/R6R w - - 0 1", "a1d1", "Rad1+"),
  ])
  func uciToSAN(fen: String, uci: String, san: String) throws {
    let replay = try GameReplay(pgn: "[FEN \"\(fen)\"]\n\n*")
    #expect(replay.san(ofUCI: uci, atPosition: 0) == san)
  }

  @Test func classificationThresholdsMatchPython() {
    #expect(MoveClassification(centipawnLoss: 0) == .best)
    #expect(MoveClassification(centipawnLoss: 19) == .best)
    #expect(MoveClassification(centipawnLoss: 20) == .good)
    #expect(MoveClassification(centipawnLoss: 50) == .inaccuracy)
    #expect(MoveClassification(centipawnLoss: 100) == .mistake)
    #expect(MoveClassification(centipawnLoss: 300) == .blunder)
  }

  @Test func scoresAreConvertedToWhitesView() {
    #expect(Evaluation(cp: 50, mate: nil, whiteToMove: false) == .centipawns(-50))
    #expect(Evaluation(cp: nil, mate: 3, whiteToMove: false) == .mate(moves: 3, whiteWins: false))
    #expect(Evaluation(cp: nil, mate: -2, whiteToMove: false) == .mate(moves: 2, whiteWins: true))
    // Side to move is mated.
    #expect(Evaluation(cp: nil, mate: 0, whiteToMove: true) == .mate(moves: 0, whiteWins: false))
    #expect(Evaluation.mate(moves: 3, whiteWins: false).whiteCentipawns == -9_997)
    #expect(Evaluation.centipawns(130).label == "+1.3")
    #expect(Evaluation.mate(moves: 2, whiteWins: false).label == "-M2")
  }

  @Test func reviewsAGame() throws {
    // 1. f3 e5 2. g4 Qh4#: White slips, then blunders; Black finds mate.
    let replay = try GameReplay(pgn: "1. f3 e5 2. g4 Qh4# 0-1")
    let positions = [
      PositionAnalysis(evaluation: .centipawns(30), bestMove: "e2e4"),
      PositionAnalysis(evaluation: .centipawns(-60), bestMove: "e7e5"),
      PositionAnalysis(evaluation: .centipawns(-70), bestMove: "g1h3"),
      PositionAnalysis(evaluation: .mate(moves: 1, whiteWins: false), bestMove: "d8h4"),
      PositionAnalysis(evaluation: .mate(moves: 0, whiteWins: false), bestMove: nil),
    ]
    let review = GameReview(replay: replay, positions: positions)
    #expect(review.moves.map(\.classification) == [.inaccuracy, .best, .blunder, .best])
    #expect(review.moves[0].centipawnLoss == 90)
    #expect(review.moves[2].bestMoveSAN == "Nh3")
    #expect(review.moves[3].playedBest && !review.moves[2].playedBest)
    #expect(review.black.accuracy > 99)
    #expect(review.white.accuracy < 60)
    #expect(review.white.count(.blunder) == 1 && review.white.count(.inaccuracy) == 1)
  }

  @Test func accuracyIsPerfectWhenNothingIsLost() {
    #expect(GameReview.accuracy(before: 40, after: 40) > 99.9)
    #expect(GameReview.accuracy(before: 40, after: 400) > 99.9)
    #expect(GameReview.accuracy(before: 300, after: -300) < 20)
  }
}

private actor Requests {
  var urls: [URL] = []
  func add(_ url: URL) { urls.append(url) }
}

@Suite struct LichessTests {
  @Test func convertsGamesAndPagesBackwards() async throws {
    let body = try #require(
      Bundle.module.url(forResource: "lichess_games", withExtension: "ndjson", subdirectory: "Fixtures"))
    let data = try Data(contentsOf: body)
    let requests = Requests()
    let fetcher = GameFetcher { request in
      await requests.add(request.url!)
      #expect(request.value(forHTTPHeaderField: "Accept") == "application/x-ndjson")
      return (data, 200)
    }

    let first = try await fetcher.firstPage(on: .lichess, for: " DrNykterstein ", limit: 3)
    #expect(first.games.count == 3 && first.cursor.hasMore)
    let game = first.games[0]
    #expect(game.site == .lichess)
    #expect(game.url == "https://lichess.org/HqjDTU4A")
    #expect(game.white.username == "DrNykterstein" && game.white.rating == 3177)
    #expect(game.outcome(for: "drnykterstein") == .win)
    #expect(game.outcome(for: "Night-King96") == .loss)
    #expect(game.timeControlDescription == "3 min")
    #expect(game.accuracies == Accuracies(white: 84, black: 79))
    #expect(game.endDate.timeIntervalSince1970 == 1_792_001_402.854)

    let replay = try GameReplay(pgn: game.pgn)
    #expect(replay.plies[1].san == "Nf6" && replay.plies[1].clock == "0:03:00")
    let opening = OpeningParser.summary(of: game, sans: replay.plies.map(\.san))
    #expect(opening.name == "Queen's Indian Accelerated" && opening.eco == "A50")

    _ = try await fetcher.nextPage(after: first.cursor, limit: 3)
    let urls = await requests.urls
    #expect(urls[0].path == "/api/games/user/DrNykterstein")
    #expect(!urls[0].query!.contains("until="))
    #expect(urls[1].query!.contains("until="), "second page should start before the oldest game")
  }

  @Test func shortPageMeansNoMore() async throws {
    let fetcher = GameFetcher { _ in (Data(), 200) }
    let page = try await fetcher.firstPage(on: .lichess, for: "newbie", limit: 5)
    #expect(page.games.isEmpty && !page.cursor.hasMore)
  }

  @Test func unknownPlayerIsTyped() async {
    let fetcher = GameFetcher { _ in (Data(), 404) }
    await #expect(throws: GameSiteError.playerNotFound("nobody")) {
      try await fetcher.firstPage(on: .lichess, for: "nobody")
    }
  }
}
