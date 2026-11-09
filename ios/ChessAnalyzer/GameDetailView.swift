import ChessCore
import SwiftUI

struct GameDetailView: View {
  private enum Tab: String, CaseIterable {
    case board = "Board"
    case stats = "Stats"
  }

  let game: ChessGame
  let username: String

  @State private var tab = Tab.board
  @State private var replay: Result<GameReplay, Error>?
  @State private var plyIndex = 0
  @State private var flipped = false

  var body: some View {
    VStack(spacing: 12) {
      Picker("View", selection: $tab) {
        ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) }
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
        if tab == .board {
          boardTab(replay)
        } else {
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
  }

  private func boardTab(_ replay: GameReplay) -> some View {
    let (top, bottom) = flipped ? (game.white, game.black) : (game.black, game.white)
    let lastPly = plyIndex > 0 ? replay.plies[plyIndex - 1] : nil

    return VStack(spacing: 8) {
      PlayerLine(player: top)
      BoardView(pieces: replay.positions[plyIndex], lastPly: lastPly, flipped: flipped)
      PlayerLine(player: bottom)
      controls(plyCount: replay.plies.count, lastPly: lastPly)
      MoveList(plies: replay.plies, plyIndex: $plyIndex)
    }
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
    Button {
      plyIndex = ply.id
    } label: {
      Text(ply.san)
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
