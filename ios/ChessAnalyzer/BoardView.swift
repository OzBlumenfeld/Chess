import ChessCore
import SwiftUI

struct BoardView: View {
  let pieces: [BoardSquare: BoardPiece]
  let lastPly: Ply?
  let flipped: Bool

  private static let light = Color(red: 0.93, green: 0.87, blue: 0.76)
  private static let dark = Color(red: 0.55, green: 0.40, blue: 0.29)
  private static let highlight = Color.yellow.opacity(0.45)

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size.width / 8
      VStack(spacing: 0) {
        ForEach(0..<8, id: \.self) { row in
          HStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { column in
              let square = BoardSquare(
                file: flipped ? 7 - column : column,
                rank: flipped ? row : 7 - row)
              squareView(square, size: size)
            }
          }
        }
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .accessibilityElement()
    .accessibilityLabel("Chess board")
  }

  private func squareView(_ square: BoardSquare, size: CGFloat) -> some View {
    let isLastMove = square == lastPly?.from || square == lastPly?.to
    return ZStack {
      (square.file + square.rank).isMultiple(of: 2) ? Self.dark : Self.light
      if isLastMove { Self.highlight }
      if let piece = pieces[square] {
        PieceView(piece: piece, size: size)
      }
    }
    .frame(width: size, height: size)
  }
}

private struct PieceView: View {
  let piece: BoardPiece
  let size: CGFloat

  /// Solid and outline glyphs. U+FE0E keeps the pawn from rendering as emoji.
  private var glyphs: (solid: String, outline: String) {
    switch piece.kind {
    case .king: ("♚\u{FE0E}", "♔\u{FE0E}")
    case .queen: ("♛\u{FE0E}", "♕\u{FE0E}")
    case .rook: ("♜\u{FE0E}", "♖\u{FE0E}")
    case .bishop: ("♝\u{FE0E}", "♗\u{FE0E}")
    case .knight: ("♞\u{FE0E}", "♘\u{FE0E}")
    case .pawn: ("♟\u{FE0E}", "♙\u{FE0E}")
    }
  }

  var body: some View {
    ZStack {
      Text(glyphs.solid).foregroundStyle(piece.isWhite ? .white : .black)
      if piece.isWhite { Text(glyphs.outline).foregroundStyle(.black) }
    }
    .font(.system(size: size * 0.8))
    .minimumScaleFactor(0.5)
    .lineLimit(1)
  }
}
