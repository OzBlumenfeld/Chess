import Foundation

/// An engine score, always from White's point of view.
public enum Evaluation: Hashable, Sendable {
  case centipawns(Int)
  /// Forced mate in `moves` (0 means the position is already mate).
  case mate(moves: Int, whiteWins: Bool)

  /// Mate scores are clamped to this many centipawns, like `analyze_games.py`.
  public static let mateScore = 10_000

  /// Converts a UCI score, which is from the side to move's point of view.
  public init(cp: Int?, mate: Int?, whiteToMove: Bool) {
    if let mate {
      // "mate 0" means the side to move is mated; otherwise the sign says who mates.
      let moverWins = mate > 0
      self = .mate(moves: abs(mate), whiteWins: moverWins == whiteToMove)
    } else {
      self = .centipawns((cp ?? 0) * (whiteToMove ? 1 : -1))
    }
  }

  /// Centipawns for White, with mate as `mateScore` minus the moves to mate.
  public var whiteCentipawns: Int {
    switch self {
    case let .centipawns(cp): cp
    case let .mate(moves, whiteWins): (Self.mateScore - moves) * (whiteWins ? 1 : -1)
    }
  }

  public func centipawns(forWhite white: Bool) -> Int {
    white ? whiteCentipawns : -whiteCentipawns
  }

  /// "+1.3", "-0.4", "M3", "-M3", or "#" once mate is on the board.
  public var label: String {
    switch self {
    case let .centipawns(cp):
      let pawns = Double(cp) / 100
      return (pawns >= 0 ? "+" : "") + pawns.formatted(.number.precision(.fractionLength(1)))
    case let .mate(moves, whiteWins):
      return moves == 0 ? "#" : (whiteWins ? "M\(moves)" : "-M\(moves)")
    }
  }
}

/// What the engine said about one position.
public struct PositionAnalysis: Hashable, Sendable {
  public let evaluation: Evaluation
  /// Best move in UCI form ("g1f3"), nil when the game is over.
  public let bestMove: String?

  public init(evaluation: Evaluation, bestMove: String?) {
    self.evaluation = evaluation
    self.bestMove = bestMove
  }
}

public enum MoveClassification: String, CaseIterable, Hashable, Sendable {
  case best, good, inaccuracy, mistake, blunder

  /// Same thresholds as `analyze_games.py`.
  public init(centipawnLoss loss: Int) {
    switch loss {
    case ..<20: self = .best
    case ..<50: self = .good
    case ..<100: self = .inaccuracy
    case ..<300: self = .mistake
    default: self = .blunder
    }
  }

  /// Annotation glyph, empty for moves that don't need one.
  public var symbol: String {
    switch self {
    case .best, .good: ""
    case .inaccuracy: "?!"
    case .mistake: "?"
    case .blunder: "??"
    }
  }
}

public struct ReviewedMove: Hashable, Sendable {
  /// Matches `Ply.id`.
  public let plyID: Int
  public let isWhite: Bool
  public let before: Evaluation
  public let after: Evaluation
  /// How much worse the mover's position got, in centipawns (never negative).
  public let centipawnLoss: Int
  public let classification: MoveClassification
  /// Lichess-style accuracy of this move, 0...100.
  public let accuracy: Double
  /// The engine's choice in the position before the move.
  public let bestMove: String?
  public let bestMoveSAN: String?
  public let playedBest: Bool
}

public struct SideSummary: Hashable, Sendable {
  public let accuracy: Double
  public let counts: [MoveClassification: Int]

  public func count(_ classification: MoveClassification) -> Int {
    counts[classification, default: 0]
  }
}

/// A whole game scored by the engine.
public struct GameReview: Sendable {
  /// One per `GameReplay.fens` entry.
  public let positions: [PositionAnalysis]
  /// One per ply; `moves[n]` is ply `n + 1`.
  public let moves: [ReviewedMove]
  public let white: SideSummary
  public let black: SideSummary

  public init(replay: GameReplay, positions: [PositionAnalysis]) {
    precondition(positions.count == replay.fens.count, "one analysis per position")
    self.positions = positions
    moves = replay.plies.map { ply in
      let before = positions[ply.id - 1]
      let after = positions[ply.id].evaluation
      let loss = max(
        0, before.evaluation.centipawns(forWhite: ply.isWhite) - after.centipawns(forWhite: ply.isWhite))
      let bestSquares = before.bestMove.flatMap(BoardSquare.move(fromUCI:))
      return ReviewedMove(
        plyID: ply.id, isWhite: ply.isWhite, before: before.evaluation, after: after,
        centipawnLoss: loss, classification: MoveClassification(centipawnLoss: loss),
        accuracy: Self.accuracy(
          before: before.evaluation.centipawns(forWhite: ply.isWhite),
          after: after.centipawns(forWhite: ply.isWhite)),
        bestMove: before.bestMove,
        bestMoveSAN: before.bestMove.flatMap { replay.san(ofUCI: $0, atPosition: ply.id - 1) },
        playedBest: bestSquares.map { $0.from == ply.from && $0.to == ply.to } ?? false)
    }
    white = Self.summary(of: moves.filter(\.isWhite))
    black = Self.summary(of: moves.filter { !$0.isWhite })
  }

  /// Lichess's win chance for a centipawn score, 0...100.
  public static func winPercent(centipawns cp: Int) -> Double {
    50 + 50 * (2 / (1 + exp(-0.00368208 * Double(cp))) - 1)
  }

  /// Lichess's move accuracy from the mover's score before and after, 0...100.
  public static func accuracy(before: Int, after: Int) -> Double {
    let drop = max(0, winPercent(centipawns: before) - winPercent(centipawns: after))
    return min(100, max(0, 103.1668 * exp(-0.04354 * drop) - 3.1669))
  }

  private static func summary(of moves: [ReviewedMove]) -> SideSummary {
    let accuracy = moves.isEmpty ? 100 : moves.map(\.accuracy).reduce(0, +) / Double(moves.count)
    var counts: [MoveClassification: Int] = [:]
    for move in moves { counts[move.classification, default: 0] += 1 }
    return SideSummary(accuracy: accuracy, counts: counts)
  }
}

extension BoardSquare {
  /// Origin and target of a UCI move such as "e2e4" or "e7e8q".
  public static func move(fromUCI uci: String) -> (from: BoardSquare, to: BoardSquare)? {
    func square(_ text: Substring) -> BoardSquare? {
      let chars = Array(text.utf8)
      guard chars.count == 2, (97...104).contains(chars[0]), (49...56).contains(chars[1]) else {
        return nil
      }
      return BoardSquare(file: Int(chars[0] - 97), rank: Int(chars[1] - 49))
    }
    guard uci.count >= 4, let from = square(uci.prefix(2)),
      let to = square(uci.dropFirst(2).prefix(2))
    else { return nil }
    return (from, to)
  }
}

extension GameReplay {
  /// SAN for a UCI move played from `positions[index]`.
  public func san(ofUCI uci: String, atPosition index: Int) -> String? {
    guard fens.indices.contains(index) else { return nil }
    return ReplayBoard(fen: fens[index])?.san(ofUCI: uci)
  }

  /// Whether White is to move in `positions[index]`.
  public func whiteToMove(atPosition index: Int) -> Bool {
    ReplayBoard(fen: fens[index])?.isWhiteToMove ?? index.isMultiple(of: 2)
  }
}
