import ChessCore
import Foundation
import Observation

/// Runs Stockfish over every position of one game and holds the result.
@Observable @MainActor
final class ReviewModel {
  enum State {
    case idle
    case running(done: Int, total: Int)
    case finished(GameReview)
    case failed(String)
  }

  private(set) var state = State.idle

  /// Search depth per position. UI tests pass `-reviewDepth 6` to stay quick.
  static let depth: Int = {
    let value = UserDefaults.standard.integer(forKey: "reviewDepth")
    return value > 0 ? value : 14
  }()

  /// The engine is shared, so only one review runs at a time app-wide.
  private static var current: Task<Void, Never>?

  private var task: Task<Void, Never>?

  var review: GameReview? {
    if case let .finished(review) = state { review } else { nil }
  }

  var isRunning: Bool {
    if case .running = state { true } else { false }
  }

  func start(_ replay: GameReplay) {
    guard !isRunning else { return }
    let previous = Self.current
    previous?.cancel()
    state = .running(done: 0, total: replay.fens.count)
    task = Task {
      await previous?.value
      await run(replay)
    }
    Self.current = task
  }

  func cancel() {
    task?.cancel()
    task = nil
    if isRunning { state = .idle }
  }

  private func run(_ replay: GameReplay) async {
    var positions: [PositionAnalysis] = []
    do {
      for (index, fen) in replay.fens.enumerated() {
        let analysis = try await StockfishEngine.shared.analyze(
          fen: fen, whiteToMove: replay.whiteToMove(atPosition: index), depth: Self.depth)
        positions.append(analysis)
        if !Task.isCancelled { state = .running(done: index + 1, total: replay.fens.count) }
      }
      state = .finished(GameReview(replay: replay, positions: positions))
    } catch is CancellationError {
      // `cancel()` already reset the state.
    } catch {
      state = .failed(error.localizedDescription)
    }
  }
}
