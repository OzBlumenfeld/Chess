import Foundation

public enum PieceKind: Sendable {
  case pawn, knight, bishop, rook, queen, king
}

public struct BoardPiece: Hashable, Sendable {
  public let kind: PieceKind
  public let isWhite: Bool
}

/// A board square, with `file` and `rank` both 0...7 from a1.
public struct BoardSquare: Hashable, Sendable {
  public let file: Int
  public let rank: Int

  public init(file: Int, rank: Int) {
    self.file = file
    self.rank = rank
  }
}

/// One half-move of the game.
public struct Ply: Hashable, Identifiable, Sendable {
  /// Position in the game: 1 is White's first move.
  public let id: Int
  public let san: String
  public let moveNumber: Int
  public let isWhite: Bool
  public let from: BoardSquare
  public let to: BoardSquare
  /// Time left after the move, e.g. "0:02:59.7", when the PGN records it.
  public let clock: String?
}

public enum GameReplayError: Error, Equatable, Sendable {
  case unreadablePGN
  case unresolvedMove(String)
}

/// A game unpacked into every position, so stepping is just an array lookup.
public struct GameReplay: Sendable {
  public let plies: [Ply]
  /// `positions[n]` is the board after `n` plies, so `positions[0]` is the start.
  public let positions: [[BoardSquare: BoardPiece]]
  /// FEN of each entry in `positions`.
  public let fens: [String]

  public init(pgn: String) throws {
    // No moves is valid: a game abandoned before the first move has none.
    let tokens = Self.moveTokens(in: pgn)
    let startFEN = Self.tag("FEN", in: pgn) ?? ReplayBoard.standardFEN
    guard var board = ReplayBoard(fen: startFEN) else { throw GameReplayError.unreadablePGN }

    var plies: [Ply] = []
    var boards = [board.pieces]
    var fens = [board.fen]
    for token in tokens {
      let isWhite = board.isWhiteToMove
      let moveNumber = board.moveNumber
      guard let (from, to) = board.play(san: token.san) else {
        throw GameReplayError.unresolvedMove(token.san)
      }
      plies.append(
        Ply(
          id: plies.count + 1, san: token.san, moveNumber: moveNumber, isWhite: isWhite,
          from: from, to: to, clock: token.clock))
      boards.append(board.pieces)
      fens.append(board.fen)
    }
    self.plies = plies
    self.positions = boards
    self.fens = fens
  }

  /// Splits movetext into SAN moves, keeping each move's `[%clk]` comment.
  private static func moveTokens(in pgn: String) -> [(san: String, clock: String?)] {
    let lines = pgn.split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("[") }
    var text = Substring(lines.joined(separator: " "))
    var tokens: [(san: String, clock: String?)] = []
    while let start = text.firstIndex(where: { !$0.isWhitespace }) {
      text = text[start...]
      if text.first == "{" {
        let end = text.firstIndex(of: "}") ?? text.endIndex
        if !tokens.isEmpty { tokens[tokens.count - 1].clock = clock(in: text[..<end]) }
        text = end < text.endIndex ? text[text.index(after: end)...] : ""
        continue
      }
      let end = text.firstIndex(where: \.isWhitespace) ?? text.endIndex
      let word = text[..<end]
      text = text[end...]
      let san = word.drop { $0.isNumber || $0 == "." }
      let isResult = ["1-0", "0-1", "1/2-1/2", "*"].contains(String(word))
      if !san.isEmpty, !isResult { tokens.append((String(san), nil)) }
    }
    return tokens
  }

  private static func clock(in comment: Substring) -> String? {
    guard let open = comment.range(of: "[%clk ") else { return nil }
    let rest = comment[open.upperBound...]
    return rest.firstIndex(of: "]").map { String(rest[..<$0]) }
  }

  private static func tag(_ tag: String, in pgn: String) -> String? {
    guard let open = pgn.range(of: "[\(tag) \"") else { return nil }
    let rest = pgn[open.upperBound...]
    return rest.range(of: "\"]").map { String(rest[..<$0.lowerBound]) }
  }
}
