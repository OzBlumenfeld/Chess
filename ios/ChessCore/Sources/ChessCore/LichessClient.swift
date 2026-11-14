import Foundation

/// Reads Lichess's public game export. No login or API token is needed.
public struct LichessClient: Sendable {
  public typealias Fetch = @Sendable (URLRequest) async throws -> (Data, Int)

  private static let api = URL(string: "https://lichess.org/api/games/user")!
  /// Every standard speed, which leaves out variants such as Chess960.
  private static let speeds = "ultraBullet,bullet,blitz,rapid,classical,correspondence"
  private let fetch: Fetch

  public init(fetch: @escaping Fetch) {
    self.fetch = fetch
  }

  public struct Cursor: Sendable {
    fileprivate let username: String
    /// Only games created before this many ms since 1970 are left to fetch.
    fileprivate let until: Int64?
    public let hasMore: Bool
  }

  /// The newest `limit` games and a cursor for `nextPage(after:)`.
  public func firstPage(
    for username: String, limit: Int = 5
  ) async throws -> (games: [ChessGame], cursor: Cursor) {
    let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
    return try await nextPage(after: Cursor(username: user, until: nil, hasMore: true), limit: limit)
  }

  /// The next `limit` older games. Fewer, or none, means the history ran out.
  public func nextPage(
    after cursor: Cursor, limit: Int = 5
  ) async throws -> (games: [ChessGame], cursor: Cursor) {
    guard cursor.hasMore else { return ([], cursor) }
    var components = URLComponents(
      url: Self.api.appendingPathComponent(cursor.username), resolvingAgainstBaseURL: false)!
    components.queryItems = [
      URLQueryItem(name: "max", value: "\(limit)"),
      URLQueryItem(name: "perfType", value: Self.speeds),
      URLQueryItem(name: "pgnInJson", value: "true"),
      URLQueryItem(name: "clocks", value: "true"),
      URLQueryItem(name: "opening", value: "true"),
      URLQueryItem(name: "accuracy", value: "true"),
    ] + (cursor.until.map { [URLQueryItem(name: "until", value: "\($0)")] } ?? [])
    var request = URLRequest(url: components.url!)
    request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")

    let (data, status) = try await fetch(request)
    if status == 404 { throw GameSiteError.playerNotFound(cursor.username) }
    guard status == 200 else { throw GameSiteError.badStatus(status) }

    let decoder = JSONDecoder()
    let exports = try data.split(separator: UInt8(ascii: "\n")).map {
      try decoder.decode(Export.self, from: Data($0))
    }
    let next = Cursor(
      username: cursor.username,
      until: exports.last.map { $0.createdAt - 1 } ?? cursor.until,
      hasMore: exports.count == limit)
    return (exports.map(\.game), next)
  }

  /// One game as Lichess exports it.
  struct Export: Decodable {
    let id: String
    let rated: Bool
    let speed: String
    let createdAt: Int64
    let lastMoveAt: Int64
    let status: String
    let players: Players
    let winner: String?
    let clock: Clock?
    let daysPerTurn: Int?
    let pgn: String

    struct Players: Decodable {
      let white: Side
      let black: Side
    }

    struct Side: Decodable {
      let user: User?
      let aiLevel: Int?
      let rating: Int?
      let analysis: Analysis?
    }

    struct User: Decodable { let name: String }
    struct Analysis: Decodable { let accuracy: Double? }
    struct Clock: Decodable {
      let initial: Int
      let increment: Int
    }

    var game: ChessGame {
      let accuracies = both(players.white.analysis?.accuracy, players.black.analysis?.accuracy)
      return ChessGame(
        uuid: id, url: "https://lichess.org/\(id)", pgn: pgn,
        timeControl: timeControl, endTime: TimeInterval(lastMoveAt) / 1000, rated: rated,
        timeClass: speed, rules: "chess",
        white: player(players.white, color: "white"), black: player(players.black, color: "black"),
        eco: nil, accuracies: accuracies.map { Accuracies(white: $0, black: $1) })
    }

    /// In chess.com's format: "180", "180+2", or "1/86400" per day for correspondence.
    private var timeControl: String {
      if let clock {
        return clock.increment == 0 ? "\(clock.initial)" : "\(clock.initial)+\(clock.increment)"
      }
      if let daysPerTurn { return "1/\(daysPerTurn * 86400)" }
      return "-"
    }

    /// Chess.com-style result: "win" for the winner, the way the game ended
    /// for the loser, and "draw" otherwise.
    private func player(_ side: Side, color: String) -> Player {
      let name = side.user?.name ?? side.aiLevel.map { "Stockfish level \($0)" } ?? "Anonymous"
      let result = winner == nil ? "draw" : (winner == color ? "win" : status)
      return Player(username: name, rating: side.rating ?? 0, result: result)
    }
  }
}

private func both<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
  guard let a, let b else { return nil }
  return (a, b)
}
