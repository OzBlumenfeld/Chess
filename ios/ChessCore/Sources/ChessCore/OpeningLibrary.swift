import Foundation

/// A named opening to study: its defining moves and the main ways it branches.
public struct Opening: Identifiable, Hashable, Sendable {
  public enum Family: String, CaseIterable, Sendable {
    case kingPawn = "1. e4"
    case queenPawn = "1. d4"
    case flank = "Flank openings"
  }

  public var id: String { name }
  public let name: String
  public let eco: String
  public let family: Family
  /// The side that chooses this opening, so the board can face them.
  public let isWhite: Bool
  /// Movetext that defines the opening, e.g. "1. e4 e5 2. Nf3 Nc6 3. Bc4".
  public let moves: String
  public let summary: String
  public let ideas: [String]
  public let variations: [OpeningVariation]
}

public struct OpeningVariation: Identifiable, Hashable, Sendable {
  public var id: String { name }
  public let name: String
  /// The whole line from move one, so it replays on its own.
  public let moves: String
  public let note: String
}

public enum OpeningLibrary {
  public static func openings(in family: Opening.Family) -> [Opening] {
    all.filter { $0.family == family }
  }

  public static let all: [Opening] = [
    // MARK: 1. e4
    Opening(
      name: "Italian Game", eco: "C50", family: .kingPawn, isWhite: true,
      moves: "1. e4 e5 2. Nf3 Nc6 3. Bc4",
      summary: "White develops quickly and aims the bishop at f7, Black's weakest square.",
      ideas: [
        "Castle early and prepare d4 with c3.",
        "The bishop on c4 eyes f7, so watch for Ng5 tricks.",
        "Black usually mirrors with ...Bc5 or counterattacks with ...Nf6.",
      ],
      variations: [
        OpeningVariation(
          name: "Giuoco Piano",
          moves: "1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. c3 Nf6 5. d4 exd4 6. cxd4 Bb4+",
          note: "White grabs the center with c3 and d4. Black checks to trade off pressure."),
        OpeningVariation(
          name: "Giuoco Pianissimo",
          moves: "1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. d3 Nf6 5. c3 d6 6. O-O O-O",
          note: "The slow, modern main line: both sides build up and maneuver."),
        OpeningVariation(
          name: "Two Knights Defense",
          moves: "1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. Ng5 d5 5. exd5 Na5 6. Bb5+ c6",
          note: "Black counterattacks e4. After Ng5 Black gives a pawn for fast development."),
        OpeningVariation(
          name: "Evans Gambit",
          moves: "1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. b4 Bxb4 5. c3 Ba5 6. d4",
          note: "White sacrifices the b-pawn to gain time for c3 and d4 and a fast attack."),
      ]),
    Opening(
      name: "Ruy Lopez", eco: "C60", family: .kingPawn, isWhite: true,
      moves: "1. e4 e5 2. Nf3 Nc6 3. Bb5",
      summary: "White pressures the knight that defends e5. One of the oldest and richest openings.",
      ideas: [
        "The bishop doesn't win e5 yet; the threat comes once d4 is played.",
        "Black often asks the bishop with ...a6 and gains space with ...b5.",
        "White plays c3, d4 and Re1 for a long-term central bind.",
      ],
      variations: [
        OpeningVariation(
          name: "Closed (Morphy Defense)",
          moves: "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3",
          note: "The classical main line. h3 stops ...Bg4 before White plays d4."),
        OpeningVariation(
          name: "Berlin Defense",
          moves: "1. e4 e5 2. Nf3 Nc6 3. Bb5 Nf6 4. O-O Nxe4 5. d4 Nd6 6. Bxc6 dxc6 7. dxe5 Nf5 8. Qxd8+ Kxd8",
          note: "The 'Berlin Wall': queens come off early and Black has a solid, hard-to-crack endgame."),
        OpeningVariation(
          name: "Exchange Variation",
          moves: "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Bxc6 dxc6 5. O-O f6",
          note: "White doubles Black's pawns, aiming for an endgame with a healthier pawn majority."),
        OpeningVariation(
          name: "Marshall Attack",
          moves: "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 O-O 8. c3 d5 9. exd5 Nxd5 10. Nxe5 Nxe5 11. Rxe5 c6",
          note: "Black sacrifices a pawn for a strong attack against White's king."),
      ]),
    Opening(
      name: "Scotch Game", eco: "C45", family: .kingPawn, isWhite: true,
      moves: "1. e4 e5 2. Nf3 Nc6 3. d4",
      summary: "White opens the center at once instead of building up slowly.",
      ideas: [
        "After ...exd4 Nxd4 White has a free, active position.",
        "Black hits the centralized knight with ...Bc5 or ...Nf6.",
      ],
      variations: [
        OpeningVariation(
          name: "Classical",
          moves: "1. e4 e5 2. Nf3 Nc6 3. d4 exd4 4. Nxd4 Bc5 5. Be3 Qf6 6. c3 Nge7",
          note: "Black piles up on the d4 knight; White keeps it defended with Be3 and c3."),
        OpeningVariation(
          name: "Schmidt (Mieses) Variation",
          moves: "1. e4 e5 2. Nf3 Nc6 3. d4 exd4 4. Nxd4 Nf6 5. Nxc6 bxc6 6. e5 Qe7 7. Qe2 Nd5 8. c4",
          note: "White trades on c6 and kicks the knight, gaining space."),
        OpeningVariation(
          name: "Scotch Gambit",
          moves: "1. e4 e5 2. Nf3 Nc6 3. d4 exd4 4. Bc4 Bc5 5. c3 Nf6",
          note: "White develops instead of recapturing and offers a pawn for activity."),
      ]),
    Opening(
      name: "King's Gambit", eco: "C30", family: .kingPawn, isWhite: true,
      moves: "1. e4 e5 2. f4",
      summary: "A romantic gambit: White offers a pawn to open the f-file and seize the center.",
      ideas: [
        "If Black takes, White plays Nf3 and d4 and attacks down the f-file.",
        "White's own king is exposed, so play must be sharp.",
      ],
      variations: [
        OpeningVariation(
          name: "Kieseritzky Gambit",
          moves: "1. e4 e5 2. f4 exf4 3. Nf3 g5 4. h4 g4 5. Ne5",
          note: "Black holds the extra pawn with ...g5; White undermines it with h4."),
        OpeningVariation(
          name: "Fischer Defense",
          moves: "1. e4 e5 2. f4 exf4 3. Nf3 d6 4. d4 g5",
          note: "...d6 keeps the knight out of e5 before Black supports the pawn."),
        OpeningVariation(
          name: "Falkbeer Countergambit",
          moves: "1. e4 e5 2. f4 d5 3. exd5 e4",
          note: "Black declines and strikes back in the center, cramping White's knight."),
        OpeningVariation(
          name: "Declined with ...Bc5",
          moves: "1. e4 e5 2. f4 Bc5 3. Nf3 d6 4. c3",
          note: "The bishop stops White from castling short; taking on e5 now runs into ...Qh4+."),
      ]),
    Opening(
      name: "Petrov Defense", eco: "C42", family: .kingPawn, isWhite: false,
      moves: "1. e4 e5 2. Nf3 Nf6",
      summary: "Black counterattacks e4 instead of defending e5. Very solid and symmetrical.",
      ideas: [
        "Never copy at once with 3. Nxe5 Nxe4? 4. Qe2: play ...d6 first.",
        "Black aims for equality and a sound pawn structure.",
      ],
      variations: [
        OpeningVariation(
          name: "Classical",
          moves: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nf3 Nxe4 5. d4 d5 6. Bd3",
          note: "Black kicks the knight first, then takes back on e4 safely."),
        OpeningVariation(
          name: "Steinitz (3. d4)",
          moves: "1. e4 e5 2. Nf3 Nf6 3. d4 Nxe4 4. Bd3 d5 5. Nxe5",
          note: "White opens the center straight away."),
      ]),
    Opening(
      name: "Sicilian Defense", eco: "B20", family: .kingPawn, isWhite: false,
      moves: "1. e4 c5",
      summary: "Black fights for d4 from the side, creating an unbalanced, double-edged game.",
      ideas: [
        "After d4 cxd4 Black trades a wing pawn for a center pawn.",
        "Black gets the half-open c-file; White often attacks the king.",
      ],
      variations: [
        OpeningVariation(
          name: "Najdorf",
          moves: "1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 a6 6. Be3 e5 7. Nb3 Be6",
          note: "...a6 keeps pieces off b5 and prepares ...e5 or ...b5. The English Attack follows."),
        OpeningVariation(
          name: "Dragon",
          moves: "1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 g6 6. Be3 Bg7 7. f3 O-O 8. Qd2 Nc6 9. Bc4 Bd7",
          note: "The Yugoslav Attack: castling on opposite sides and racing to mate."),
        OpeningVariation(
          name: "Sveshnikov",
          moves: "1. e4 c5 2. Nf3 Nc6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 e5 6. Ndb5 d6 7. Bg5 a6 8. Na3 b5",
          note: "Black accepts a hole on d5 for active pieces and space on the queenside."),
        OpeningVariation(
          name: "Kan",
          moves: "1. e4 c5 2. Nf3 e6 3. d4 cxd4 4. Nxd4 a6 5. Bd3",
          note: "A flexible setup: Black keeps pawns on e6 and a6 and waits to develop."),
        OpeningVariation(
          name: "Alapin (2. c3)",
          moves: "1. e4 c5 2. c3 d5 3. exd5 Qxd5 4. d4 Nf6 5. Nf3",
          note: "White avoids the main lines and prepares d4 so it can be taken back with a pawn."),
      ]),
    Opening(
      name: "French Defense", eco: "C00", family: .kingPawn, isWhite: false,
      moves: "1. e4 e6 2. d4 d5",
      summary: "Black builds a solid pawn chain and challenges White's center from behind.",
      ideas: [
        "Black's light-squared bishop is often the problem piece.",
        "Attack White's chain at its base with ...c5 and ...f6.",
      ],
      variations: [
        OpeningVariation(
          name: "Winawer",
          moves: "1. e4 e6 2. d4 d5 3. Nc3 Bb4 4. e5 c5 5. a3 Bxc3+ 6. bxc3 Ne7",
          note: "Black gives up the bishop to double White's pawns. Sharp and strategic."),
        OpeningVariation(
          name: "Classical",
          moves: "1. e4 e6 2. d4 d5 3. Nc3 Nf6 4. Bg5 Be7 5. e5 Nfd7 6. Bxe7 Qxe7",
          note: "White pushes e5 and trades the dark-squared bishops."),
        OpeningVariation(
          name: "Advance",
          moves: "1. e4 e6 2. d4 d5 3. e5 c5 4. c3 Nc6 5. Nf3 Qb6",
          note: "White grabs space; Black piles up on d4."),
        OpeningVariation(
          name: "Tarrasch",
          moves: "1. e4 e6 2. d4 d5 3. Nd2 c5 4. exd5 exd5 5. Ngf3 Nc6",
          note: "Nd2 avoids the Winawer pin. Black often ends up with an isolated d-pawn."),
        OpeningVariation(
          name: "Exchange",
          moves: "1. e4 e6 2. d4 d5 3. exd5 exd5 4. Bd3 Bd6",
          note: "A symmetrical structure that frees Black's light-squared bishop."),
      ]),
    Opening(
      name: "Caro-Kann Defense", eco: "B10", family: .kingPawn, isWhite: false,
      moves: "1. e4 c6",
      summary: "Black prepares ...d5 with the c-pawn. Like the French, but Black keeps the light-squared bishop free to develop.",
      ideas: [
        "Get the bishop out to f5 or g4 before playing ...e6.",
        "Solid structure, good endgames, fewer early tactics.",
      ],
      variations: [
        OpeningVariation(
          name: "Classical",
          moves: "1. e4 c6 2. d4 d5 3. Nc3 dxe4 4. Nxe4 Bf5 5. Ng3 Bg6 6. h4 h6 7. Nf3 Nd7 8. h5 Bh7",
          note: "White chases the bishop with h4–h5 to gain space on the kingside."),
        OpeningVariation(
          name: "Advance",
          moves: "1. e4 c6 2. d4 d5 3. e5 Bf5 4. Nf3 e6 5. Be2",
          note: "White gains space; Black develops the bishop first, then plays ...e6 and ...c5."),
        OpeningVariation(
          name: "Panov Attack",
          moves: "1. e4 c6 2. d4 d5 3. exd5 cxd5 4. c4 Nf6 5. Nc3 e6 6. Nf3",
          note: "White plays c4 for an open game, often with an isolated queen's pawn."),
        OpeningVariation(
          name: "Two Knights",
          moves: "1. e4 c6 2. Nc3 d5 3. Nf3 Bg4",
          note: "White develops instead of committing the d-pawn."),
      ]),
    Opening(
      name: "Scandinavian Defense", eco: "B01", family: .kingPawn, isWhite: false,
      moves: "1. e4 d5 2. exd5",
      summary: "Black challenges e4 immediately and gets a clear, simple position.",
      ideas: [
        "Taking back with the queen costs time after Nc3, but the position is solid.",
        "Develop with ...Nf6, ...c6 and ...Bf5.",
      ],
      variations: [
        OpeningVariation(
          name: "Main Line (...Qa5)",
          moves: "1. e4 d5 2. exd5 Qxd5 3. Nc3 Qa5 4. d4 Nf6 5. Nf3 c6",
          note: "The queen pins along the diagonal and keeps an eye on e5."),
        OpeningVariation(
          name: "Modern (...Qd6)",
          moves: "1. e4 d5 2. exd5 Qxd5 3. Nc3 Qd6 4. d4 Nf6 5. Nf3 a6",
          note: "A more central queen that can't be hit by Bd2 tricks."),
        OpeningVariation(
          name: "Marshall (2...Nf6)",
          moves: "1. e4 d5 2. exd5 Nf6 3. d4 Nxd5 4. Nf3",
          note: "Black takes back with the knight and avoids losing time with the queen."),
      ]),
    Opening(
      name: "Pirc Defense", eco: "B07", family: .kingPawn, isWhite: false,
      moves: "1. e4 d6 2. d4 Nf6 3. Nc3 g6",
      summary: "Black lets White build a big center, planning to undermine it later.",
      ideas: [
        "Fianchetto the bishop on g7 and castle.",
        "Strike back with ...e5 or ...c5 once developed.",
      ],
      variations: [
        OpeningVariation(
          name: "Austrian Attack",
          moves: "1. e4 d6 2. d4 Nf6 3. Nc3 g6 4. f4 Bg7 5. Nf3 O-O",
          note: "White builds a huge pawn center and threatens e5."),
        OpeningVariation(
          name: "Classical",
          moves: "1. e4 d6 2. d4 Nf6 3. Nc3 g6 4. Nf3 Bg7 5. Be2 O-O 6. O-O",
          note: "A calm setup where White simply develops."),
      ]),

    // MARK: 1. d4
    Opening(
      name: "Queen's Gambit Declined", eco: "D30", family: .queenPawn, isWhite: false,
      moves: "1. d4 d5 2. c4 e6",
      summary: "Black keeps the d5 pawn firmly defended. A classical, rock-solid defense.",
      ideas: [
        "Black's light-squared bishop is shut in by e6; ...b6 and ...Bb7 is one fix.",
        "Freeing breaks are ...c5 and ...e5.",
      ],
      variations: [
        OpeningVariation(
          name: "Tartakower",
          moves: "1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Be7 5. e3 O-O 6. Nf3 h6 7. Bh4 b6",
          note: "Black solves the bishop problem with a fianchetto on b7."),
        OpeningVariation(
          name: "Exchange",
          moves: "1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. cxd5 exd5 5. Bg5 c6 6. e3 Be7 7. Bd3",
          note: "White fixes the structure and aims for a minority attack with b4–b5."),
        OpeningVariation(
          name: "Ragozin",
          moves: "1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Nf3 Bb4",
          note: "A Nimzo-Indian flavor: Black pins the knight for active play."),
      ]),
    Opening(
      name: "Queen's Gambit Accepted", eco: "D20", family: .queenPawn, isWhite: false,
      moves: "1. d4 d5 2. c4 dxc4",
      summary: "Black takes the pawn, not to keep it, but to get free development.",
      ideas: [
        "Don't hold c4 with ...b5: White wins it back and more.",
        "Black hits the center with ...c5.",
      ],
      variations: [
        OpeningVariation(
          name: "Classical",
          moves: "1. d4 d5 2. c4 dxc4 3. Nf3 Nf6 4. e3 e6 5. Bxc4 c5 6. O-O a6",
          note: "White regains the pawn; Black prepares ...b5 and ...Bb7."),
        OpeningVariation(
          name: "Central (3. e4)",
          moves: "1. d4 d5 2. c4 dxc4 3. e4 e5 4. Nf3 exd4 5. Bxc4",
          note: "White builds the full center at once; Black strikes back immediately."),
      ]),
    Opening(
      name: "Slav Defense", eco: "D10", family: .queenPawn, isWhite: false,
      moves: "1. d4 d5 2. c4 c6",
      summary: "Black supports d5 with the c-pawn, keeping the light-squared bishop free.",
      ideas: [
        "Black can take on c4 and develop the bishop to f5.",
        "With ...e6 too it becomes the Semi-Slav, a sharper system.",
      ],
      variations: [
        OpeningVariation(
          name: "Main Line",
          moves: "1. d4 d5 2. c4 c6 3. Nf3 Nf6 4. Nc3 dxc4 5. a4 Bf5",
          note: "a4 stops ...b5. Black develops the bishop before ...e6."),
        OpeningVariation(
          name: "Semi-Slav (Meran)",
          moves: "1. d4 d5 2. c4 c6 3. Nf3 Nf6 4. Nc3 e6 5. e3 Nbd7 6. Bd3 dxc4 7. Bxc4 b5",
          note: "Black gains queenside space and plans ...Bb7 and ...c5."),
        OpeningVariation(
          name: "Exchange",
          moves: "1. d4 d5 2. c4 c6 3. cxd5 cxd5 4. Nc3 Nf6 5. Bf4",
          note: "Symmetrical and quiet. White hopes to use the extra tempo."),
      ]),
    Opening(
      name: "King's Indian Defense", eco: "E60", family: .queenPawn, isWhite: false,
      moves: "1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 4. e4 d6",
      summary: "Black allows a big center, then counterattacks it, often with a kingside pawn storm.",
      ideas: [
        "Black breaks with ...e5 or ...c5.",
        "When the center locks, White attacks on the queenside, Black on the kingside.",
      ],
      variations: [
        OpeningVariation(
          name: "Classical",
          moves: "1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 4. e4 d6 5. Nf3 O-O 6. Be2 e5 7. O-O Nc6 8. d5 Ne7",
          note: "The center closes; Black follows with ...Nd7 and ...f5."),
        OpeningVariation(
          name: "Sämisch",
          moves: "1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 4. e4 d6 5. f3 O-O 6. Be3 e5",
          note: "f3 rock-solidly supports e4 and prepares Qd2 and a kingside attack."),
        OpeningVariation(
          name: "Four Pawns Attack",
          moves: "1. d4 Nf6 2. c4 g6 3. Nc3 Bg7 4. e4 d6 5. f4 O-O 6. Nf3 c5",
          note: "White grabs maximum space; Black must hit the center fast."),
      ]),
    Opening(
      name: "Nimzo-Indian Defense", eco: "E20", family: .queenPawn, isWhite: false,
      moves: "1. d4 Nf6 2. c4 e6 3. Nc3 Bb4",
      summary: "Black pins the knight to stop e4, ready to trade bishop for knight.",
      ideas: [
        "Black often doubles White's c-pawns with ...Bxc3.",
        "White gets the bishop pair; Black gets a better structure.",
      ],
      variations: [
        OpeningVariation(
          name: "Rubinstein (4. e3)",
          moves: "1. d4 Nf6 2. c4 e6 3. Nc3 Bb4 4. e3 O-O 5. Bd3 d5 6. Nf3 c5",
          note: "White develops quietly and aims for central play."),
        OpeningVariation(
          name: "Classical (4. Qc2)",
          moves: "1. d4 Nf6 2. c4 e6 3. Nc3 Bb4 4. Qc2 O-O 5. a3 Bxc3+ 6. Qxc3 b6",
          note: "The queen recaptures so White's pawns stay healthy."),
        OpeningVariation(
          name: "Sämisch (4. a3)",
          moves: "1. d4 Nf6 2. c4 e6 3. Nc3 Bb4 4. a3 Bxc3+ 5. bxc3 c5",
          note: "White accepts doubled pawns for the bishop pair and a strong center."),
      ]),
    Opening(
      name: "Grünfeld Defense", eco: "D80", family: .queenPawn, isWhite: false,
      moves: "1. d4 Nf6 2. c4 g6 3. Nc3 d5",
      summary: "Black invites White to build a big center and then attacks it with pieces.",
      ideas: [
        "The g7 bishop bears down on d4.",
        "...c5 and ...Nc6 add pressure on White's center.",
      ],
      variations: [
        OpeningVariation(
          name: "Exchange",
          moves: "1. d4 Nf6 2. c4 g6 3. Nc3 d5 4. cxd5 Nxd5 5. e4 Nxc3 6. bxc3 Bg7 7. Nf3 c5",
          note: "White gets the ideal center; the whole game revolves around it."),
        OpeningVariation(
          name: "Russian System",
          moves: "1. d4 Nf6 2. c4 g6 3. Nc3 d5 4. Nf3 Bg7 5. Qb3 dxc4 6. Qxc4 O-O 7. e4",
          note: "White uses the queen to support e4."),
      ]),
    Opening(
      name: "London System", eco: "D02", family: .queenPawn, isWhite: true,
      moves: "1. d4 d5 2. Bf4",
      summary: "A setup White can play against almost anything: bishop to f4, then e3, c3 and Nf3.",
      ideas: [
        "Get the bishop out before playing e3.",
        "A sturdy pyramid of pawns on c3, d4 and e3.",
        "Ne5 and a kingside attack are common plans.",
      ],
      variations: [
        OpeningVariation(
          name: "Main Line",
          moves: "1. d4 d5 2. Bf4 Nf6 3. e3 e6 4. Nf3 c5 5. c3 Nc6 6. Nbd2 Bd6 7. Bg3",
          note: "White keeps the bishop rather than trading it on d6."),
        OpeningVariation(
          name: "Against ...Bd6",
          moves: "1. d4 d5 2. Bf4 Nf6 3. e3 e6 4. Nf3 Bd6 5. Bg3 O-O 6. Nbd2 c5 7. c3",
          note: "Bg3 meets the bishop trade offer; taking on g3 opens the h-file for White."),
        OpeningVariation(
          name: "Against ...c5 and ...Qb6",
          moves: "1. d4 d5 2. Bf4 c5 3. e3 Nc6 4. c3 Qb6 5. Qb3 c4 6. Qc2",
          note: "Black hits b2, the London's soft spot. White offers a queen trade."),
      ]),
    Opening(
      name: "Dutch Defense", eco: "A80", family: .queenPawn, isWhite: false,
      moves: "1. d4 f5",
      summary: "Black grabs e4 from the side and plans play on the kingside.",
      ideas: [
        "Black weakens the king a little for central control.",
        "Different pawn setups give different systems.",
      ],
      variations: [
        OpeningVariation(
          name: "Leningrad",
          moves: "1. d4 f5 2. c4 Nf6 3. g3 g6 4. Bg2 Bg7 5. Nf3 O-O 6. O-O d6",
          note: "Black fianchettoes, like a King's Indian with ...f5 already played."),
        OpeningVariation(
          name: "Stonewall",
          moves: "1. d4 f5 2. g3 Nf6 3. Bg2 e6 4. Nf3 d5 5. O-O Bd6 6. c4 c6",
          note: "Pawns on c6, d5, e6 and f5 give Black a grip on e4, at the cost of e5."),
        OpeningVariation(
          name: "Classical",
          moves: "1. d4 f5 2. g3 Nf6 3. Bg2 e6 4. Nf3 Be7 5. O-O O-O 6. c4 d6",
          note: "Flexible: Black keeps ...e5 in reserve."),
      ]),

    // MARK: Flank
    Opening(
      name: "English Opening", eco: "A10", family: .flank, isWhite: true,
      moves: "1. c4",
      summary: "White controls d5 from the side, often with a kingside fianchetto.",
      ideas: [
        "Often plays like a Sicilian with colors reversed.",
        "g3 and Bg2 put pressure on the long diagonal.",
      ],
      variations: [
        OpeningVariation(
          name: "Four Knights",
          moves: "1. c4 e5 2. Nc3 Nf6 3. Nf3 Nc6 4. g3",
          note: "A reversed Sicilian with an extra tempo for White."),
        OpeningVariation(
          name: "Symmetrical",
          moves: "1. c4 c5 2. Nc3 Nc6 3. g3 g6 4. Bg2 Bg7",
          note: "Both sides fianchetto and fight for d5 and d4."),
        OpeningVariation(
          name: "Mikenas Attack",
          moves: "1. c4 Nf6 2. Nc3 e6 3. e4",
          note: "White grabs the center with e4 and dares Black to push ...d5."),
      ]),
    Opening(
      name: "Réti Opening", eco: "A04", family: .flank, isWhite: true,
      moves: "1. Nf3 d5",
      summary: "White develops first and decides on a pawn structure later.",
      ideas: [
        "Pressure the center from a distance with c4 and g3.",
        "Can transpose into many 1. d4 or 1. c4 openings.",
      ],
      variations: [
        OpeningVariation(
          name: "Réti Main Line",
          moves: "1. Nf3 d5 2. c4 e6 3. g3 Nf6 4. Bg2 Be7 5. O-O O-O",
          note: "c4 hits d5 from the side; White keeps flexible."),
        OpeningVariation(
          name: "King's Indian Attack",
          moves: "1. Nf3 d5 2. g3 Nf6 3. Bg2 e6 4. O-O Be7 5. d3 O-O 6. Nbd2 c5 7. e4",
          note: "A setup White can use against nearly anything, aiming for e5 and a kingside attack."),
      ]),
  ]
}
