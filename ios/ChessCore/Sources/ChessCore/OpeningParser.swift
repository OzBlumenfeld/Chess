import Foundation

/// What each side played in the opening. Chess.com reports one opening per
/// game, so crediting it to a player is derived, see `chooser(of:)`.
public struct OpeningSummary: Hashable, Sendable {
  public let eco: String?
  public let name: String?
  public let whiteFirstMove: String?
  public let blackFirstMove: String?

  /// The named opening if White is credited with choosing it.
  public var whiteChoice: String? { credited(to: .white) }
  /// The named opening if Black is credited with choosing it.
  public var blackChoice: String? { credited(to: .black) }

  private func credited(to side: OpeningParser.Side) -> String? {
    guard let name, OpeningParser.chooser(of: name) == side else { return nil }
    return name
  }
}

public enum OpeningParser {
  public enum Side: Sendable {
    case white, black
  }

  public static func summary(of game: ChessGame, sans: [String]) -> OpeningSummary {
    let url = game.eco ?? game.pgnTag("ECOUrl")
    return OpeningSummary(
      eco: game.pgnTag("ECO"),
      name: url.flatMap(name(fromURL:)),
      whiteFirstMove: sans.first,
      blackFirstMove: sans.dropFirst().first
    )
  }

  /// The opening name from a chess.com URL. Slugs run on into the moves, as in
  /// `Sicilian-Defense-Canal-Attack...4.Ba4-Nf6-5.O-O` or
  /// `Caro-Kann-Defense-Advance-Short-Variation-with-4-Nf3...e6`, so cut where
  /// the moves start. Slugs drop apostrophes: "Kings Gambit".
  public static func name(fromURL url: String) -> String? {
    guard let slug = url.split(separator: "/").last, url.contains("/openings/") else {
      return nil
    }
    var text = String(slug)
    if let moves = text.range(of: #"-with-\d|\.\.\.|-\d+\."#, options: .regularExpression) {
      text = String(text[..<moves.lowerBound])
    }
    let name = text.replacingOccurrences(of: "-", with: " ")
    return name.isEmpty || name == "Undefined" ? nil : name
  }

  /// A heuristic: defenses are Black's choice and everything else is White's.
  public static func chooser(of name: String) -> Side {
    let lowered = name.lowercased()
    return lowered.contains("defense") || lowered.contains("countergambit") ? .black : .white
  }
}
