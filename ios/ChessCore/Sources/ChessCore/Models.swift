import Foundation

public enum Outcome: Sendable {
  case win, loss, draw
}

public struct Player: Codable, Hashable, Sendable {
  public let username: String
  public let rating: Int
  public let result: String

  public init(username: String, rating: Int, result: String) {
    self.username = username
    self.rating = rating
    self.result = result
  }
}

public struct Accuracies: Codable, Hashable, Sendable {
  public let white: Double
  public let black: Double

  public init(white: Double, black: Double) {
    self.white = white
    self.black = black
  }
}

/// One game from a chess.com monthly archive.
public struct ChessGame: Codable, Hashable, Identifiable, Sendable {
  public let uuid: String
  public let url: String
  public let pgn: String
  public let timeControl: String
  public let endTime: TimeInterval
  public let rated: Bool
  public let timeClass: String
  public let rules: String
  public let white: Player
  public let black: Player
  public let eco: String?
  public let accuracies: Accuracies?

  public init(
    uuid: String, url: String, pgn: String, timeControl: String, endTime: TimeInterval,
    rated: Bool, timeClass: String, rules: String, white: Player, black: Player,
    eco: String?, accuracies: Accuracies?
  ) {
    self.uuid = uuid
    self.url = url
    self.pgn = pgn
    self.timeControl = timeControl
    self.endTime = endTime
    self.rated = rated
    self.timeClass = timeClass
    self.rules = rules
    self.white = white
    self.black = black
    self.eco = eco
    self.accuracies = accuracies
  }

  public var id: String { uuid }
  public var site: GameSite { url.contains("lichess.org") ? .lichess : .chessCom }
  public var endDate: Date { Date(timeIntervalSince1970: endTime) }

  enum CodingKeys: String, CodingKey {
    case uuid, url, pgn, rated, rules, white, black, eco, accuracies
    case timeControl = "time_control"
    case endTime = "end_time"
    case timeClass = "time_class"
  }

  public func isWhite(_ username: String) -> Bool {
    white.username.caseInsensitiveCompare(username) == .orderedSame
  }

  /// Result from `username`'s side. Every non-win pair of results is a draw.
  public func outcome(for username: String) -> Outcome {
    let (me, them) = isWhite(username) ? (white, black) : (black, white)
    if me.result == "win" { return .win }
    if them.result == "win" { return .loss }
    return .draw
  }

  /// A PGN header value, e.g. `pgnTag("Termination")`.
  public func pgnTag(_ tag: String) -> String? {
    guard let open = pgn.range(of: "[\(tag) \"") else { return nil }
    let rest = pgn[open.upperBound...]
    return rest.range(of: "\"]").map { String(rest[..<$0.lowerBound]) }
  }

  /// "180" -> "3 min", "180+2" -> "3 min + 2s", "1/86400" -> "1 day per move".
  public var timeControlDescription: String {
    if timeControl.hasPrefix("1/"), let seconds = Int(timeControl.dropFirst(2)) {
      let days = seconds / 86400
      return "\(days) day\(days == 1 ? "" : "s") per move"
    }
    let parts = timeControl.split(separator: "+")
    guard let base = parts.first.flatMap({ Int($0) }) else { return timeControl }
    let start = base < 60 ? "\(base)s" : "\(base / 60) min"
    return parts.count > 1 ? "\(start) + \(parts[1])s" : start
  }
}
