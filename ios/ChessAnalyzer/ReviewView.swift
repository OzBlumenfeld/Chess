import Charts
import ChessCore
import SwiftUI

/// Engine review summary: accuracy, mistake counts, eval graph and key moments.
struct ReviewView: View {
  let game: ChessGame
  let replay: GameReplay
  let review: GameReview
  /// Called with a ply index (0 is the start) when the user picks a moment.
  let onSelect: (Int) -> Void

  private static let clamp = 10.0
  private static let counted: [MoveClassification] = [.inaccuracy, .mistake, .blunder]

  var body: some View {
    Form {
      Section {
        summaryRow(game.white.username, review.white)
        summaryRow(game.black.username, review.black)
      } header: {
        Text("Accuracy")
      } footer: {
        Text("Stockfish 17 at depth \(ReviewModel.depth). ?! inaccuracy, ? mistake, ?? blunder.")
      }

      Section("Evaluation") {
        chart.frame(height: 180)
      }

      let moments = review.moves.filter { $0.classification == .mistake || $0.classification == .blunder }
      if !moments.isEmpty {
        Section("Key moments") {
          ForEach(moments, id: \.plyID) { momentRow($0) }
        }
      }
    }
  }

  private func summaryRow(_ name: String, _ side: SideSummary) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(name).font(.headline)
        Spacer()
        Text(side.accuracy.formatted(.number.precision(.fractionLength(1))) + "%")
          .font(.headline.monospacedDigit())
      }
      HStack(spacing: 12) {
        ForEach(Self.counted, id: \.self) { kind in
          Label(kind.counted(side.count(kind)), systemImage: "circle.fill")
            .labelStyle(DotLabelStyle(color: kind.color))
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }

  private var chart: some View {
    Chart {
      ForEach(Array(review.positions.enumerated()), id: \.offset) { index, position in
        let pawns = min(Self.clamp, max(-Self.clamp, Double(position.evaluation.whiteCentipawns) / 100))
        AreaMark(x: .value("Ply", index), y: .value("Eval", pawns))
          .foregroundStyle(Color.gray.opacity(0.35))
        LineMark(x: .value("Ply", index), y: .value("Eval", pawns))
          .foregroundStyle(Color.primary)
          .lineStyle(StrokeStyle(lineWidth: 1))
      }
      ForEach(review.moves.filter { $0.classification == .blunder || $0.classification == .mistake }, id: \.plyID) {
        move in
        let pawns = min(Self.clamp, max(-Self.clamp, Double(move.after.whiteCentipawns) / 100))
        PointMark(x: .value("Ply", move.plyID), y: .value("Eval", pawns))
          .foregroundStyle(move.classification.color)
          .symbolSize(30)
      }
      RuleMark(y: .value("Even", 0)).foregroundStyle(.secondary.opacity(0.5))
    }
    .chartYScale(domain: -Self.clamp...Self.clamp)
    .chartXScale(domain: 0...max(1, review.positions.count - 1))
    .chartYAxis {
      AxisMarks(values: [-10, -5, 0, 5, 10]) { AxisGridLine(); AxisValueLabel() }
    }
    .chartOverlay { proxy in
      GeometryReader { geometry in
        Rectangle().fill(.clear).contentShape(.rect)
          .onTapGesture { location in
            guard let plot = proxy.plotFrame else { return }
            let x = location.x - geometry[plot].origin.x
            guard let ply: Int = proxy.value(atX: x) else { return }
            onSelect(min(max(ply, 0), review.positions.count - 1))
          }
      }
    }
    .accessibilityLabel("Evaluation graph")
  }

  private func momentRow(_ move: ReviewedMove) -> some View {
    let ply = replay.plies[move.plyID - 1]
    return Button {
      onSelect(move.plyID)
    } label: {
      HStack {
        Text("\(ply.moveNumber)\(ply.isWhite ? "." : "...") \(ply.san)\(move.classification.symbol)")
          .foregroundStyle(move.classification.color)
          .font(.body.monospacedDigit().weight(.semibold))
        Spacer()
        if let best = move.bestMoveSAN {
          Text("Best \(best)").foregroundStyle(.secondary)
        }
        Text("\(move.before.label) → \(move.after.label)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      }
    }
    .buttonStyle(.plain)
  }
}

private struct DotLabelStyle: LabelStyle {
  let color: Color

  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 3) {
      configuration.icon.foregroundStyle(color).imageScale(.small)
      configuration.title
    }
  }
}

extension MoveClassification {
  /// "1 mistake", "3 inaccuracies".
  func counted(_ count: Int) -> String {
    let noun = count == 1 ? rawValue : (self == .inaccuracy ? "inaccuracies" : rawValue + "s")
    return "\(count) \(noun)"
  }

  var color: Color {
    switch self {
    case .best: .green
    case .good: .secondary
    case .inaccuracy: Color(red: 0.85, green: 0.65, blue: 0)
    case .mistake: .orange
    case .blunder: .red
    }
  }
}
