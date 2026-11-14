import ChessCore
import ChessKitEngine
import Foundation

/// Stockfish 17 running in-process. Stockfish keeps global state, so the app
/// shares one engine and `ReviewModel` runs one review at a time.
actor StockfishEngine {
  enum Failure: LocalizedError {
    case missingNetworks
    case didNotStart

    var errorDescription: String? {
      switch self {
      case .missingNetworks:
        "The Stockfish network files aren't in the app. Run ios/scripts/fetch-nnue.sh and rebuild."
      case .didNotStart: "Stockfish didn't start."
      }
    }
  }

  static let shared = StockfishEngine()

  private static let networks = [
    "EvalFile": "nn-1111cefa1111",
    "EvalFileSmall": "nn-37f18f62d772",
  ]

  private let engine = Engine(type: .stockfish)
  private var started = false
  private var listener: Task<Void, Never>?

  // State of the command in flight; the listener fills it in.
  private var infos: [EngineResponse.Info] = []
  private var bestMove: String??
  private var searchWaiter: CheckedContinuation<Void, Never>?
  private var readyWaiter: CheckedContinuation<Void, Never>?
  private var isReady = false

  /// Scores `fen` to `depth`. Cancelling the calling task stops the search early.
  func analyze(fen: String, whiteToMove: Bool, depth: Int) async throws -> PositionAnalysis {
    try await startIfNeeded()
    infos = []
    bestMove = nil
    await engine.send(command: .position(.fen(fen)))
    await withTaskCancellationHandler {
      await engine.send(command: .go(depth: depth))
      if bestMove == nil {
        await withCheckedContinuation { searchWaiter = $0 }
      }
    } onCancel: {
      Task { await self.engine.send(command: .stop) }
    }
    // Responses are delivered on separate tasks, so wait out stragglers from
    // this search before the next one starts.
    await waitUntilReady()
    try Task.checkCancellation()

    // Lines can arrive out of order, and stragglers from the previous search
    // can sneak in, so trust the deepest line that leads with the final move.
    let best = bestMove ?? nil
    let matching = infos.filter { best != nil && $0.pv?.first == best }
    let deepest = (matching.isEmpty ? infos : matching).max { ($0.depth ?? 0) < ($1.depth ?? 0) }
    let score = deepest?.score
    let evaluation = Evaluation(
      cp: score?.cp.map { Int($0.rounded()) }, mate: score?.mate, whiteToMove: whiteToMove)
    return PositionAnalysis(evaluation: evaluation, bestMove: best)
  }

  private func startIfNeeded() async throws {
    guard !started else { return }
    let paths = Self.networks.compactMapValues {
      Bundle.main.url(forResource: $0, withExtension: "nnue")?.path()
    }
    guard paths.count == Self.networks.count else { throw Failure.missingNetworks }

    await engine.start(coreCount: ProcessInfo.processInfo.activeProcessorCount)
    var attempts = 0
    while !(await engine.isRunning), attempts < 100 {
      attempts += 1
      try await Task.sleep(for: .milliseconds(100))
    }
    guard await engine.isRunning, let stream = await engine.responseStream else {
      throw Failure.didNotStart
    }
    listener = Task { [weak self] in
      for await response in stream { await self?.receive(response) }
    }
    started = true

    // ChessKitEngine sets these too, but racing it; set them before the first
    // search so Stockfish never looks for a network it doesn't have.
    for (option, path) in paths {
      await engine.send(command: .setoption(id: option, value: path))
    }
    await engine.send(command: .setoption(id: "Hash", value: "64"))
    await waitUntilReady()
  }

  private func waitUntilReady() async {
    isReady = false
    await engine.send(command: .isready)
    if !isReady {
      await withCheckedContinuation { readyWaiter = $0 }
    }
  }

  private func receive(_ response: EngineResponse) {
    switch response {
    case let .info(info):
      // Bound scores are provisional.
      guard info.score != nil, info.multipv ?? 1 == 1,
        info.score?.lowerbound != true, info.score?.upperbound != true
      else { return }
      infos.append(info)
    case let .bestmove(move, _):
      bestMove = .some(move == "(none)" ? nil : move)
      searchWaiter?.resume()
      searchWaiter = nil
    case .readyok:
      isReady = true
      readyWaiter?.resume()
      readyWaiter = nil
    default:
      break
    }
  }
}
