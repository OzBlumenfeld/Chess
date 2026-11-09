import ChessCore
import SwiftUI

struct SearchView: View {
  private enum Phase {
    case idle
    case loading
    case loaded(username: String, games: [ChessGame], cursor: ChessComClient.Cursor)
    case failed(String)
  }

  /// A new value restarts the fetch, even for the same nickname.
  private struct Search: Equatable {
    let id = UUID()
    let username: String
  }

  private static let pageSize = 5

  @AppStorage("lastNickname") private var nickname = ""
  @State private var search: Search?
  @State private var phase = Phase.idle
  @State private var loadingMore = false
  @State private var loadMoreError: String?
  @FocusState private var fieldFocused: Bool

  var body: some View {
    NavigationStack {
      List {
        Section {
          TextField("Chess.com nickname", text: $nickname)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($fieldFocused)
            .onSubmit(submit)
          Button("Find games", action: submit)
            .disabled(trimmedNickname.isEmpty)
        }
        results
      }
      .scrollDismissesKeyboard(.immediately)
      .navigationTitle("Chess Analyzer")
      .navigationDestination(for: GameRoute.self) { route in
        GameDetailView(game: route.game, username: route.username)
      }
      .task(id: search) { await load() }
    }
  }

  private var trimmedNickname: String {
    nickname.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  @ViewBuilder private var results: some View {
    switch phase {
    case .idle:
      EmptyView()
    case .loading:
      Section {
        HStack {
          Spacer()
          ProgressView()
          Spacer()
        }
      }
    case let .failed(message):
      Section { Text(message).foregroundStyle(.secondary) }
    case let .loaded(username, games, _) where games.isEmpty:
      Section { Text("\(username) has no standard games yet.").foregroundStyle(.secondary) }
    case let .loaded(username, games, cursor):
      Section("Latest \(games.count) games") {
        ForEach(games) { game in
          NavigationLink(value: GameRoute(game: game, username: username)) {
            GameRow(game: game, username: username)
          }
        }
      }
      Section {
        if cursor.hasMore {
          loadMoreButton
        } else {
          Text("No older games.").foregroundStyle(.secondary)
        }
        if let loadMoreError {
          Text(loadMoreError).foregroundStyle(.secondary)
        }
      }
    }
  }

  private var loadMoreButton: some View {
    Button {
      Task { await loadMore() }
    } label: {
      HStack {
        Text("Load \(Self.pageSize) more")
        Spacer()
        if loadingMore { ProgressView() }
      }
    }
    .disabled(loadingMore)
  }

  private func submit() {
    guard !trimmedNickname.isEmpty else { return }
    fieldFocused = false
    search = Search(username: trimmedNickname)
  }

  private func load() async {
    guard let search else { return }
    phase = .loading
    loadMoreError = nil
    do {
      let page = try await ChessComClient().firstPage(for: search.username, limit: Self.pageSize)
      phase = .loaded(username: search.username, games: page.games, cursor: page.cursor)
    } catch is CancellationError {
      return  // a newer search took over
    } catch let error as URLError where error.code == .cancelled {
      return
    } catch {
      phase = .failed(message(for: error, username: search.username))
    }
  }

  private func loadMore() async {
    guard case let .loaded(username, games, cursor) = phase, let search, !loadingMore else {
      return
    }
    loadingMore = true
    loadMoreError = nil
    defer { loadingMore = false }
    do {
      let page = try await ChessComClient().nextPage(after: cursor, limit: Self.pageSize)
      guard self.search?.id == search.id else { return }  // a new search started meanwhile
      phase = .loaded(username: username, games: games + page.games, cursor: page.cursor)
    } catch {
      guard self.search?.id == search.id else { return }
      loadMoreError = message(for: error, username: username)
    }
  }

  private func message(for error: Error, username: String) -> String {
    switch error {
    case ChessComError.playerNotFound:
      "No chess.com player named \(username)."
    case ChessComError.badStatus(429):
      "Chess.com is rate limiting requests. Try again in a minute."
    case is URLError:
      "Couldn't reach chess.com. Check your connection."
    default:
      "Chess.com sent something unexpected. Try again."
    }
  }
}

struct GameRoute: Hashable {
  let game: ChessGame
  let username: String
}

private struct GameRow: View {
  let game: ChessGame
  let username: String

  var body: some View {
    let isWhite = game.isWhite(username)
    let (me, opponent) = isWhite ? (game.white, game.black) : (game.black, game.white)
    let outcome = game.outcome(for: username)

    HStack(spacing: 12) {
      Text(outcome.letter)
        .font(.headline)
        .frame(width: 28, height: 28)
        .background(outcome.color.opacity(0.2), in: .circle)
        .foregroundStyle(outcome.color)
        .accessibilityLabel(outcome.label)
      VStack(alignment: .leading, spacing: 2) {
        Text("vs \(opponent.username) (\(opponent.rating))").font(.body)
        Text("\(isWhite ? "White" : "Black"), \(me.rating) · \(game.timeClass.capitalized)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Text(game.endDate, format: .dateTime.month(.abbreviated).day())
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

extension Outcome {
  fileprivate var letter: String {
    switch self {
    case .win: "W"
    case .loss: "L"
    case .draw: "D"
    }
  }

  fileprivate var label: String {
    switch self {
    case .win: "Win"
    case .loss: "Loss"
    case .draw: "Draw"
    }
  }

  fileprivate var color: Color {
    switch self {
    case .win: .green
    case .loss: .red
    case .draw: .secondary
    }
  }
}
