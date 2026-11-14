import ChessCore
import SwiftUI

struct GameDetailView: View {
  private enum Tab: String, CaseIterable {
    case board = "Board"
    case review = "Review"
    case stats = "Stats"
  }

  let game: ChessGame
  let username: String

  @State private var tab = Tab.board
  @State private var replay: Result<GameReplay, Error>?
  @State private var plyIndex = 0
  @State private var flipped = false
  @State private var reviewModel = ReviewModel()

  private var tabs: [Tab] {
    reviewModel.review == nil ? [.board, .stats] : Tab.allCases
  }

  var body: some View {
    VStack(spacing: 12) {
      Picker("View", selection: $tab) {
        ForEach(tabs, id: \.self) { Text($0.rawValue) }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)

      switch replay {
      case nil:
        ProgressView().frame(maxHeight: .infinity)
      case let .failure(error):
        ContentUnavailableView(
          "Can't show this game", systemImage: "exclamationmark.triangle",
          description: Text(String(describing: error)))
      case let .success(replay):
        switch tab {
        case .board:
          boardTab(replay)
        case .review:
          if let review = reviewModel.review {
            ReviewView(game: game, replay: replay, review: review) { ply in
              plyIndex = ply
              tab = .board
            }
          }
        case .stats:
          StatsView(
            game: game,
            opening: OpeningParser.summary(of: game, sans: replay.plies.map(\.san)))
        }
      }
    }
    .navigationTitle("\(game.white.username) vs \(game.black.username)")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if tab == .board {
        Button("Flip board", systemImage: "arrow.up.arrow.down") { flipped.toggle() }
      }
    }
    .task {
      guard replay == nil else { return }
      flipped = !game.isWhite(username)
      replay = Result { try GameReplay(pgn: game.pgn) }
    }
    .onDisappear { reviewModel.cancel() }
  }

  private func boardTab(_ replay: GameReplay) -> some View {
    let (top, bottom) = flipped ? (game.white, game.black) : (game.black, game.white)
    let lastPly = plyIndex > 0 ? replay.plies[plyIndex - 1] : nil
    let review = reviewModel.review
    let arrow = review?.positions[plyIndex].bestMove.flatMap(BoardSquare.move(fromUCI:))

    return VStack(spacing: 8) {
      PlayerLine(player: top)
      HStack(spacing: 4) {
        if let review {
          EvalBar(evaluation: review.positions[plyIndex].evaluation, flipped: flipped)
        }
        BoardView(pieces: replay.positions[plyIndex], lastPly: lastPly, flipped: flipped, arrow: arrow)
      }
      .padding(.horizontal, review == nil ? 0 : 4)
      PlayerLine(player: bottom)
      controls(plyCount: replay.plies.count, lastPly: lastPly)
      reviewLine(replay)
      MoveList(plies: replay.plies, reviewed: review?.moves, plyIndex: $plyIndex)
    }
  }

  @ViewBuilder
  private func reviewLine(_ replay: GameReplay) -> some View {
    Group {
      switch reviewModel.state {
      case .idle:
        Button("Review game", systemImage: "cpu") { reviewModel.start(replay) }
          .buttonStyle(.borderedProminent)
          .disabled(replay.plies.isEmpty)
      case let .running(done, total):
        HStack {
          ProgressView(value: Double(done), total: Double(total))
          Text("Analyzing \(done)/\(total)").font(.caption.monospacedDigit())
          Button("Cancel review", systemImage: "xmark.circle.fill") { reviewModel.cancel() }
            .labelStyle(.iconOnly)
        }
      case let .failed(message):
        VStack(spacing: 4) {
          Text(message).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
          Button("Retry review") { reviewModel.start(replay) }
        }
      case let .finished(review):
        moveVerdict(review, replay)
      }
    }
    .padding(.horizontal)
    .frame(minHeight: 32)
  }

  private func moveVerdict(_ review: GameReview, _ replay: GameReplay) -> some View {
    let position = review.positions[plyIndex]
    let best = position.bestMove.flatMap { replay.san(ofUCI: $0, atPosition: plyIndex) }
    return HStack(spacing: 6) {
      if plyIndex > 0 {
        let move = review.moves[plyIndex - 1]
        Text(move.playedBest ? "Best move" : move.classification.rawValue.capitalized)
          .foregroundStyle(move.classification.color)
          .fontWeight(.semibold)
        if !move.playedBest, let previous = move.bestMoveSAN {
          Text("· best was \(previous)").foregroundStyle(.secondary)
        }
      }
      Spacer()
      if let best {
        Text("Engine: \(best)").foregroundStyle(.blue)
      }
    }
    .font(.subheadline)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("moveVerdict")
  }

  private func controls(plyCount: Int, lastPly: Ply?) -> some View {
    HStack {
      stepButton("Start", "backward.end.fill", to: 0, enabled: plyIndex > 0)
      stepButton("Previous move", "chevron.left", to: plyIndex - 1, enabled: plyIndex > 0)
      Text(lastPly?.label ?? (plyCount == 0 ? "No moves played" : "Start"))
        .font(.headline.monospacedDigit())
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("currentMove")
      stepButton("Next move", "chevron.right", to: plyIndex + 1, enabled: plyIndex < plyCount)
      stepButton("End", "forward.end.fill", to: plyCount, enabled: plyIndex < plyCount)
    }
    .padding(.horizontal)
  }

  private func stepButton(_ title: String, _ icon: String, to index: Int, enabled: Bool) -> some View {
    Button(title, systemImage: icon) { plyIndex = index }
      .labelStyle(.iconOnly)
      .font(.title2)
      .frame(width: 44, height: 44)
      .contentShape(.rect)
      .disabled(!enabled)
  }
}

private struct PlayerLine: View {
  let player: Player

  var body: some View {
    HStack {
      Text(player.username).font(.subheadline.weight(.semibold))
      Text("\(player.rating)").font(.subheadline).foregroundStyle(.secondary)
      Spacer()
    }
    .padding(.horizontal)
  }
}

private struct MoveList: View {
  let plies: [Ply]
  /// Engine verdicts, indexed like `plies`, once the game is reviewed.
  let reviewed: [ReviewedMove]?
  @Binding var plyIndex: Int

  private var rows: [[Ply]] {
    stride(from: 0, to: plies.count, by: 2).map { Array(plies[$0..<min($0 + 2, plies.count)]) }
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 2) {
          ForEach(rows, id: \.first?.id) { row in
            HStack(spacing: 8) {
              Text("\(row[0].moveNumber).")
                .frame(width: 40, alignment: .trailing)
                .foregroundStyle(.secondary)
              ForEach(row) { moveButton($0) }
              if row.count == 1 { Spacer().frame(maxWidth: .infinity) }
            }
            .id(row[0].id)
          }
        }
        .font(.subheadline.monospacedDigit())
        .padding(.horizontal)
      }
      .onChange(of: plyIndex) {
        guard plyIndex > 0 else { return }
        withAnimation { proxy.scrollTo((plyIndex - 1) / 2 * 2 + 1, anchor: .center) }
      }
    }
  }

  private func moveButton(_ ply: Ply) -> some View {
    let verdict = reviewed?[ply.id - 1].classification
    return Button {
      plyIndex = ply.id
    } label: {
      Text(ply.san + (verdict?.symbol ?? ""))
        .foregroundStyle(verdict.map { $0.symbol.isEmpty ? Color.primary : $0.color } ?? .primary)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .background(ply.id == plyIndex ? Color.accentColor.opacity(0.2) : .clear, in: .rect(cornerRadius: 4))
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}

extension Ply {
  fileprivate var label: String {
    "\(moveNumber)\(isWhite ? "." : "...") \(san)"
  }
}
