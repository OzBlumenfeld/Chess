import ChessCore
import SwiftUI

/// Browse openings by first move and step through each one's lines on a board.
struct OpeningsView: View {
  var body: some View {
    NavigationStack {
      List {
        ForEach(Opening.Family.allCases, id: \.self) { family in
          Section(family.rawValue) {
            ForEach(OpeningLibrary.openings(in: family)) { opening in
              NavigationLink(value: opening) { OpeningRow(opening: opening) }
            }
          }
        }
      }
      .navigationTitle("Openings")
      .navigationDestination(for: Opening.self) { OpeningDetailView(opening: $0) }
    }
  }
}

private struct OpeningRow: View {
  let opening: Opening

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(opening.name).font(.headline)
        Spacer()
        Text(opening.eco).font(.caption.monospaced()).foregroundStyle(.secondary)
      }
      Text(opening.moves).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
      Text("\(opening.variations.count) lines · for \(opening.isWhite ? "White" : "Black")")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 2)
  }
}

struct OpeningDetailView: View {
  let opening: Opening
  /// How many plies define the opening itself; later plies belong to a variation.
  private let baseLength: Int

  init(opening: Opening) {
    self.opening = opening
    baseLength = (try? GameReplay(pgn: opening.moves))?.plies.count ?? 0
  }

  /// nil shows just the opening's defining moves.
  @State private var variation: OpeningVariation?
  @State private var plyIndex = 0
  @State private var flipped = false
  @State private var playing = false

  private var replay: GameReplay? {
    try? GameReplay(pgn: variation?.moves ?? opening.moves)
  }

  var body: some View {
    VStack(spacing: 8) {
      lineChips
      if let replay {
        let lastPly = plyIndex > 0 ? replay.plies[plyIndex - 1] : nil
        BoardView(pieces: replay.positions[plyIndex], lastPly: lastPly, flipped: flipped)
          .padding(.horizontal, 8)
        controls(plyCount: replay.plies.count, lastPly: lastPly)
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            moveGrid(replay.plies)
            explanation
          }
          .padding(.horizontal)
          .padding(.bottom)
        }
      } else {
        ContentUnavailableView("Can't show this line", systemImage: "exclamationmark.triangle")
      }
    }
    .navigationTitle(opening.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      Button("Flip board", systemImage: "arrow.up.arrow.down") { flipped.toggle() }
    }
    .onAppear { flipped = !opening.isWhite }
    .task(id: playing) { await autoplay() }
  }

  // MARK: Line picker

  private var lineChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        chip("Opening moves", selected: variation == nil) { select(nil) }
        ForEach(opening.variations) { line in
          chip(line.name, selected: variation == line) { select(line) }
        }
      }
      .padding(.horizontal)
    }
  }

  private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(selected ? Color.white : Color.primary)
        .background(
          selected ? Color.accentColor : Color.secondary.opacity(0.15), in: .capsule)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  /// A new line starts where it branches off, so the next tap shows its first new move.
  private func select(_ line: OpeningVariation?) {
    playing = false
    variation = line
    plyIndex = line == nil ? 0 : baseLength
  }

  // MARK: Controls

  private func controls(plyCount: Int, lastPly: Ply?) -> some View {
    HStack {
      stepButton("Start", "backward.end.fill", to: 0, enabled: plyIndex > 0)
      stepButton("Previous move", "chevron.left", to: plyIndex - 1, enabled: plyIndex > 0)
      Text(lastPly.map { label($0) } ?? "Start")
        .font(.headline.monospacedDigit())
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("currentMove")
      stepButton("Next move", "chevron.right", to: plyIndex + 1, enabled: plyIndex < plyCount)
      stepButton("End", "forward.end.fill", to: plyCount, enabled: plyIndex < plyCount)
      Button(playing ? "Pause" : "Play", systemImage: playing ? "pause.fill" : "play.fill") {
        if !playing, plyIndex == plyCount { plyIndex = 0 }
        playing.toggle()
      }
      .labelStyle(.iconOnly)
      .font(.title2)
      .frame(width: 44, height: 44)
      .contentShape(.rect)
      .disabled(plyCount == 0)
    }
    .padding(.horizontal)
  }

  private func stepButton(_ title: String, _ icon: String, to index: Int, enabled: Bool) -> some View {
    Button(title, systemImage: icon) {
      playing = false
      plyIndex = index
    }
    .labelStyle(.iconOnly)
    .font(.title2)
    .frame(width: 44, height: 44)
    .contentShape(.rect)
    .disabled(!enabled)
  }

  private func autoplay() async {
    guard playing, let count = replay?.plies.count else { return }
    while plyIndex < count {
      try? await Task.sleep(for: .seconds(1))
      guard playing, !Task.isCancelled else { return }
      plyIndex += 1
    }
    playing = false
  }

  // MARK: Moves and notes

  private func moveGrid(_ plies: [Ply]) -> some View {
    let rows = stride(from: 0, to: plies.count, by: 2).map {
      Array(plies[$0..<min($0 + 2, plies.count)])
    }
    return VStack(alignment: .leading, spacing: 6) {
      Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 2) {
        ForEach(rows, id: \.first?.id) { row in
          GridRow {
            Text("\(row[0].moveNumber).")
              .foregroundStyle(.secondary)
              .gridColumnAlignment(.trailing)
            ForEach(row) { moveButton($0) }
            if row.count == 1 { Color.clear.frame(height: 1) }
          }
        }
      }
      .font(.subheadline.monospacedDigit())
      if let variation {
        Text("Bold moves are the \(opening.name); the rest is the \(variation.name).")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func moveButton(_ ply: Ply) -> some View {
    Button {
      playing = false
      plyIndex = ply.id
    } label: {
      Text(ply.san)
        .fontWeight(ply.id <= baseLength ? .semibold : .regular)
        .foregroundStyle(ply.id <= baseLength || variation == nil ? Color.primary : Color.accentColor)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          ply.id == plyIndex ? Color.accentColor.opacity(0.2) : .clear, in: .rect(cornerRadius: 4)
        )
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder private var explanation: some View {
    if let variation {
      VStack(alignment: .leading, spacing: 6) {
        Text(variation.name).font(.headline)
        Text(variation.note)
      }
    } else {
      VStack(alignment: .leading, spacing: 6) {
        Text(opening.summary)
        Text("Key ideas").font(.headline).padding(.top, 6)
        ForEach(opening.ideas, id: \.self) { idea in
          Label(idea, systemImage: "lightbulb")
            .labelStyle(IdeaLabelStyle())
        }
        Text("Pick a line above to see how the opening continues.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.top, 4)
      }
    }
  }

  private func label(_ ply: Ply) -> String {
    "\(ply.moveNumber)\(ply.isWhite ? "." : "...") \(ply.san)"
  }
}

private struct IdeaLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      configuration.icon.foregroundStyle(.yellow)
      configuration.title
    }
  }
}
