import ChessCore
import SwiftUI

/// Vertical evaluation bar: White's share fills from White's side of the board.
struct EvalBar: View {
  let evaluation: Evaluation?
  let flipped: Bool

  /// White's share, 0...1, from Lichess's win chance so big leads saturate.
  private var whiteShare: Double {
    guard let evaluation else { return 0.5 }
    return GameReview.winPercent(centipawns: evaluation.whiteCentipawns) / 100
  }

  var body: some View {
    GeometryReader { geometry in
      let height = geometry.size.height
      ZStack(alignment: flipped ? .top : .bottom) {
        Color(white: 0.2)
        Color(white: 0.95).frame(height: height * whiteShare)
      }
      .overlay(alignment: whiteShare >= 0.5 ? (flipped ? .top : .bottom) : (flipped ? .bottom : .top)) {
        if let evaluation {
          Text(evaluation.label.replacingOccurrences(of: "+", with: ""))
            .font(.system(size: 9, weight: .semibold).monospacedDigit())
            .foregroundStyle(whiteShare >= 0.5 ? .black : .white)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .padding(.vertical, 3)
        }
      }
      .animation(.easeInOut(duration: 0.25), value: whiteShare)
    }
    .frame(width: 18)
    .clipShape(.rect(cornerRadius: 2))
    .accessibilityElement()
    .accessibilityLabel("Evaluation")
    .accessibilityValue(evaluation?.label ?? "Unknown")
  }
}
