import Foundation

/// Where games are fetched from.
public enum GameSite: String, CaseIterable, Hashable, Sendable {
  case chessCom = "chesscom"
  case lichess

  public var name: String {
    switch self {
    case .chessCom: "Chess.com"
    case .lichess: "Lichess"
    }
  }
}

public enum GameSiteError: Error, Equatable, Sendable {
  case playerNotFound(String)
  case badStatus(Int)
  case invalidResponse
}

/// Where a player's history was left off on either site.
public enum GameCursor: Sendable {
  case chessCom(ChessComClient.Cursor)
  case lichess(LichessClient.Cursor)

  public var hasMore: Bool {
    switch self {
    case let .chessCom(cursor): cursor.hasMore
    case let .lichess(cursor): cursor.hasMore
    }
  }
}

/// Pages through a player's games on whichever site they play on.
public struct GameFetcher: Sendable {
  public typealias Fetch = @Sendable (URLRequest) async throws -> (Data, Int)

  private let fetch: Fetch

  public init(fetch: @escaping Fetch = GameFetcher.urlSessionFetch) {
    self.fetch = fetch
  }

  public static let urlSessionFetch: Fetch = { request in
    var request = request
    request.setValue("chess-analyzer-ios", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw GameSiteError.invalidResponse }
    return (data, http.statusCode)
  }

  public func firstPage(
    on site: GameSite, for username: String, limit: Int = 5
  ) async throws -> (games: [ChessGame], cursor: GameCursor) {
    switch site {
    case .chessCom:
      let page = try await chessCom.firstPage(for: username, limit: limit)
      return (page.games, .chessCom(page.cursor))
    case .lichess:
      let page = try await lichess.firstPage(for: username, limit: limit)
      return (page.games, .lichess(page.cursor))
    }
  }

  public func nextPage(
    after cursor: GameCursor, limit: Int = 5
  ) async throws -> (games: [ChessGame], cursor: GameCursor) {
    switch cursor {
    case let .chessCom(cursor):
      let page = try await chessCom.nextPage(after: cursor, limit: limit)
      return (page.games, .chessCom(page.cursor))
    case let .lichess(cursor):
      let page = try await lichess.nextPage(after: cursor, limit: limit)
      return (page.games, .lichess(page.cursor))
    }
  }

  private var chessCom: ChessComClient {
    ChessComClient { [fetch] url in try await fetch(URLRequest(url: url)) }
  }

  private var lichess: LichessClient { LichessClient(fetch: fetch) }
}
