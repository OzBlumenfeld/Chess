import Foundation

/// Just enough chess to replay a finished game. SAN from chess.com is always
/// legal, so this resolves which piece moved and never generates moves.
struct ReplayBoard {
  private var squares: [BoardPiece?]
  private var whiteToMove: Bool
  private var castling: String
  private var enPassant: Int?
  private var halfmove: Int
  private var fullmove: Int

  static let standardFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

  private static let kinds: [Character: PieceKind] = [
    "p": .pawn, "n": .knight, "b": .bishop, "r": .rook, "q": .queen, "k": .king,
  ]
  private static let rookLines = [(1, 0), (-1, 0), (0, 1), (0, -1)]
  private static let bishopLines = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
  private static let knightJumps = [
    (1, 2), (2, 1), (-1, 2), (-2, 1), (1, -2), (2, -1), (-1, -2), (-2, -1),
  ]
  /// Castling rights lost when a piece leaves or lands on a square.
  private static let rightsLost: [Int: String] = [
    0: "Q", 4: "KQ", 7: "K", 56: "q", 60: "kq", 63: "k",
  ]

  init?(fen: String) {
    let fields = fen.split(separator: " ")
    guard fields.count == 6 else { return nil }
    let ranks = fields[0].split(separator: "/")
    guard ranks.count == 8 else { return nil }

    squares = Array(repeating: nil, count: 64)
    for (row, text) in ranks.enumerated() {
      var file = 0
      for character in text {
        if let gap = character.wholeNumberValue {
          file += gap
        } else if let kind = Self.kinds[Character(character.lowercased())], file < 8 {
          squares[(7 - row) * 8 + file] = BoardPiece(kind: kind, isWhite: character.isUppercase)
          file += 1
        } else {
          return nil
        }
      }
      guard file == 8 else { return nil }
    }
    guard let halfmove = Int(fields[4]), let fullmove = Int(fields[5]) else { return nil }
    whiteToMove = fields[1] == "w"
    castling = fields[2] == "-" ? "" : String(fields[2])
    enPassant = Self.index(of: fields[3])
    self.halfmove = halfmove
    self.fullmove = fullmove
  }

  var fen: String {
    var rows: [String] = []
    for rank in (0..<8).reversed() {
      var row = ""
      var gap = 0
      for file in 0..<8 {
        guard let piece = squares[rank * 8 + file] else {
          gap += 1
          continue
        }
        if gap > 0 { row += String(gap) }
        gap = 0
        let letter = Self.letter(of: piece.kind)
        row += piece.isWhite ? letter.uppercased() : letter
      }
      if gap > 0 { row += String(gap) }
      rows.append(row)
    }
    let passant = enPassant.map { Self.name(of: $0) } ?? "-"
    let side = whiteToMove ? "w" : "b"
    let rights = castling.isEmpty ? "-" : castling
    return "\(rows.joined(separator: "/")) \(side) \(rights) \(passant) \(halfmove) \(fullmove)"
  }

  var pieces: [BoardSquare: BoardPiece] {
    var pieces: [BoardSquare: BoardPiece] = [:]
    for (index, piece) in squares.enumerated() {
      if let piece { pieces[Self.square(index)] = piece }
    }
    return pieces
  }

  var isWhiteToMove: Bool { whiteToMove }
  var moveNumber: Int { fullmove }

  /// Plays a SAN move and returns its squares, or nil if it can't be resolved.
  mutating func play(san: String) -> (from: BoardSquare, to: BoardSquare)? {
    let text = san.filter { !"+#!?".contains($0) }
    guard let (from, to, promotion) = resolve(text) else { return nil }
    let piece = squares[from]
    let isCapture = squares[to] != nil || (piece?.kind == .pawn && from % 8 != to % 8)
    let isDoublePush = piece?.kind == .pawn && abs(to - from) == 16

    self = moved(from: from, to: to, promotion: promotion)
    castling.removeAll { Self.rightsLost[from]?.contains($0) == true }
    castling.removeAll { Self.rightsLost[to]?.contains($0) == true }
    enPassant = isDoublePush ? (from + to) / 2 : nil
    halfmove = isCapture || piece?.kind == .pawn ? 0 : halfmove + 1
    if !whiteToMove { fullmove += 1 }
    whiteToMove.toggle()
    return (Self.square(from), Self.square(to))
  }

  /// SAN for a legal move written in UCI form ("g1f3", "e7e8q"), or nil if
  /// the side to move has no piece on its origin. Checks get `+`; mate is
  /// not detected, so it is also written `+`.
  func san(ofUCI uci: String) -> String? {
    guard uci.count >= 4,
      let from = Self.index(of: Substring(uci.prefix(2))),
      let to = Self.index(of: Substring(uci.dropFirst(2).prefix(2))),
      let piece = squares[from], piece.isWhite == whiteToMove
    else { return nil }
    let promotion = uci.dropFirst(4).first.flatMap { Self.kinds[Character($0.lowercased())] }
    let isCapture = squares[to] != nil || (piece.kind == .pawn && from % 8 != to % 8)
    let target = Self.name(of: to)

    var san: String
    if piece.kind == .king, abs(to - from) == 2 {
      san = to > from ? "O-O" : "O-O-O"
    } else if piece.kind == .pawn {
      san = (isCapture ? "\(Self.name(of: from).first!)x" : "") + target
      if let promotion { san += "=" + Self.letter(of: promotion).uppercased() }
    } else {
      let rivals = squares.indices.filter {
        $0 != from && squares[$0] == piece && attacks(from: $0, to: to)
          && !leavesKingInCheck(from: $0, to: to)
      }
      let origin = Self.name(of: from)
      let hint: String
      if rivals.isEmpty {
        hint = ""
      } else if !rivals.contains(where: { $0 % 8 == from % 8 }) {
        hint = String(origin.first!)
      } else if !rivals.contains(where: { $0 / 8 == from / 8 }) {
        hint = String(origin.last!)
      } else {
        hint = origin
      }
      san = Self.letter(of: piece.kind).uppercased() + hint + (isCapture ? "x" : "") + target
    }

    let next = moved(from: from, to: to, promotion: promotion)
    let enemyKing = BoardPiece(kind: .king, isWhite: !whiteToMove)
    if let king = next.squares.firstIndex(of: enemyKing),
      next.squares.indices.contains(where: {
        next.squares[$0]?.isWhite == whiteToMove && next.attacks(from: $0, to: king)
      })
    {
      san += "+"
    }
    return san
  }

  private static func letter(of kind: PieceKind) -> String {
    String(kinds.first { $0.value == kind }!.key)
  }

  private func resolve(_ text: String) -> (from: Int, to: Int, promotion: PieceKind?)? {
    let backRank = whiteToMove ? 0 : 56
    if text == "O-O" || text == "0-0" { return (backRank + 4, backRank + 6, nil) }
    if text == "O-O-O" || text == "0-0-0" { return (backRank + 4, backRank + 2, nil) }

    let parts = text.split(separator: "=")
    guard let body = parts.first, body.count >= 2 else { return nil }
    guard let to = Self.index(of: body.suffix(2)) else { return nil }
    let promotion = parts.count > 1 ? parts[1].first.flatMap { Self.kinds[Character($0.lowercased())] } : nil
    let prefix = body.dropLast(2).filter { $0 != "x" }

    let from: Int?
    if let first = prefix.first, first.isUppercase {
      guard let kind = Self.kinds[Character(first.lowercased())] else { return nil }
      from = origin(of: kind, to: to, hint: prefix.dropFirst())
    } else {
      from = pawnOrigin(to: to, fromFile: prefix.first)
    }
    return from.map { ($0, to, promotion) }
  }

  /// The one piece of `kind` that can legally reach `to`, nil unless exactly one can.
  private func origin(of kind: PieceKind, to: Int, hint: Substring) -> Int? {
    let candidates = squares.indices.filter { index in
      guard let piece = squares[index], piece.kind == kind, piece.isWhite == whiteToMove else {
        return false
      }
      return attacks(from: index, to: to)
        && hint.allSatisfy { Self.name(of: index).contains($0) }
        && !leavesKingInCheck(from: index, to: to)
    }
    return candidates.count == 1 ? candidates[0] : nil
  }

  private func pawnOrigin(to: Int, fromFile: Character?) -> Int? {
    let step = whiteToMove ? 8 : -8
    let pawn = BoardPiece(kind: .pawn, isWhite: whiteToMove)
    if let fromFile {
      guard let ascii = fromFile.asciiValue, (97...104).contains(ascii) else { return nil }
      let from = (to - step) / 8 * 8 + Int(ascii - 97)
      guard squares.indices.contains(from), squares[from] == pawn else { return nil }
      return squares[to] != nil || to == enPassant ? from : nil
    }
    guard squares[to] == nil, squares.indices.contains(to - step) else { return nil }
    if squares[to - step] == pawn { return to - step }
    let startRank = whiteToMove ? 1 : 6
    let from = to - 2 * step
    let canDouble = squares.indices.contains(from) && from / 8 == startRank
    return canDouble && squares[to - step] == nil && squares[from] == pawn ? from : nil
  }

  /// Moves the pieces only. `play` handles the bookkeeping fields.
  private func moved(from: Int, to: Int, promotion: PieceKind?) -> ReplayBoard {
    var next = self
    guard let piece = squares[from] else { return next }
    if piece.kind == .pawn, from % 8 != to % 8, squares[to] == nil {
      next.squares[from / 8 * 8 + to % 8] = nil  // en passant
    }
    if piece.kind == .king, abs(to - from) == 2 {
      let (rookFrom, rookTo) = to > from ? (to + 1, to - 1) : (to - 2, to + 1)
      next.squares[rookTo] = next.squares[rookFrom]
      next.squares[rookFrom] = nil
    }
    next.squares[from] = nil
    next.squares[to] = promotion.map { BoardPiece(kind: $0, isWhite: piece.isWhite) } ?? piece
    return next
  }

  private func leavesKingInCheck(from: Int, to: Int) -> Bool {
    let next = moved(from: from, to: to, promotion: nil)
    let king = BoardPiece(kind: .king, isWhite: whiteToMove)
    guard let square = next.squares.firstIndex(of: king) else { return false }
    return next.squares.indices.contains { index in
      guard let piece = next.squares[index], piece.isWhite != whiteToMove else { return false }
      return next.attacks(from: index, to: square)
    }
  }

  /// Whether the piece on `from` attacks `to`, ignoring pins.
  private func attacks(from: Int, to: Int) -> Bool {
    guard let piece = squares[from], from != to else { return false }
    let files = to % 8 - from % 8
    let ranks = to / 8 - from / 8
    switch piece.kind {
    case .pawn: return abs(files) == 1 && ranks == (piece.isWhite ? 1 : -1)
    case .knight: return Self.knightJumps.contains { $0 == (files, ranks) }
    case .king: return abs(files) <= 1 && abs(ranks) <= 1
    case .bishop: return slides(from: from, files: files, ranks: ranks, along: Self.bishopLines)
    case .rook: return slides(from: from, files: files, ranks: ranks, along: Self.rookLines)
    case .queen:
      return slides(from: from, files: files, ranks: ranks, along: Self.rookLines + Self.bishopLines)
    }
  }

  private func slides(from: Int, files: Int, ranks: Int, along lines: [(Int, Int)]) -> Bool {
    let distance = max(abs(files), abs(ranks))
    guard lines.contains(where: { $0.0 * distance == files && $0.1 * distance == ranks }) else {
      return false
    }
    let step = files.signum() + ranks.signum() * 8
    return (1..<distance).allSatisfy { squares[from + step * $0] == nil }
  }

  private static func square(_ index: Int) -> BoardSquare {
    BoardSquare(file: index % 8, rank: index / 8)
  }

  private static func name(of index: Int) -> String {
    let file = Character(UnicodeScalar(UInt8(97 + index % 8)))
    return "\(file)\(index / 8 + 1)"
  }

  private static func index(of name: Substring) -> Int? {
    let chars = Array(name.utf8)
    guard chars.count == 2, (97...104).contains(chars[0]), (49...56).contains(chars[1]) else {
      return nil
    }
    return Int(chars[1] - 49) * 8 + Int(chars[0] - 97)
  }
}
