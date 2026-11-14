import Foundation

public typealias ChessComError = GameSiteError

/// Reads chess.com's public API. No login or API key is needed.
public struct ChessComClient: Sendable {
  public typealias Fetch = @Sendable (URL) async throws -> (Data, Int)

  private static let api = URL(string: "https://api.chess.com/pub/player")!
  private let fetch: Fetch

  public init(fetch: @escaping Fetch = ChessComClient.urlSessionFetch) {
    self.fetch = fetch
  }

  public static let urlSessionFetch: Fetch = { url in
    var request = URLRequest(url: url)
    request.setValue("chess-analyzer-ios", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw ChessComError.invalidResponse
    }
    return (data, http.statusCode)
  }

  /// Where a player's game history was left off, for loading older games.
  public struct Cursor: Sendable {
    /// Archives not fetched yet, oldest first, as chess.com lists them.
    fileprivate var archives: [URL]
    /// Games already fetched but not returned yet, newest first.
    fileprivate var buffered: [ChessGame]

    /// False once every archive is read and every game returned.
    public var hasMore: Bool { !archives.isEmpty || !buffered.isEmpty }
  }

  /// The `limit` most recent standard-chess games, newest first.
  public func recentGames(for username: String, limit: Int = 5) async throws -> [ChessGame] {
    try await firstPage(for: username, limit: limit).games
  }

  /// The newest `limit` games and a cursor for `nextPage(after:)`.
  public func firstPage(
    for username: String, limit: Int = 5
  ) async throws -> (games: [ChessGame], cursor: Cursor) {
    let user = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let url = Self.api.appendingPathComponent(user).appendingPathComponent("games/archives")
    guard let list: ArchiveList = try await get(url) else {
      throw ChessComError.playerNotFound(user)
    }
    return try await nextPage(after: Cursor(archives: list.archives, buffered: []), limit: limit)
  }

  /// The next `limit` older games. Fewer, or none, means the history ran out.
  ///
  /// Archives and the games inside them are oldest first, and a month may be
  /// short, so this walks backwards a month at a time until it has enough.
  public func nextPage(
    after cursor: Cursor, limit: Int = 5
  ) async throws -> (games: [ChessGame], cursor: Cursor) {
    var cursor = cursor
    while cursor.buffered.count < limit, let archive = cursor.archives.popLast() {
      // Chess.com can list a month and then 404 on it, so a miss here says
      // nothing about the player. Skip to the month before.
      guard let month: GameList = try await get(archive) else { continue }
      cursor.buffered += month.games.filter { $0.rules == "chess" }.reversed()
    }
    let games = Array(cursor.buffered.prefix(limit))
    cursor.buffered.removeFirst(games.count)
    return (games, cursor)
  }

  /// Decoded response, or nil on a 404.
  private func get<T: Decodable>(_ url: URL) async throws -> T? {
    let (data, status) = try await fetch(url)
    if status == 404 { return nil }
    guard status == 200 else { throw ChessComError.badStatus(status) }
    return try JSONDecoder().decode(T.self, from: data)
  }

  private struct ArchiveList: Decodable {
    let archives: [URL]
  }

  private struct GameList: Decodable {
    let games: [ChessGame]
  }
}
