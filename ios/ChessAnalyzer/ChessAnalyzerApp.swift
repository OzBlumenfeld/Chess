import SwiftUI

@main
struct ChessAnalyzerApp: App {
  init() {
    // UI tests start from a clean slate rather than the last nickname searched.
    if CommandLine.arguments.contains("-resetForUITests") {
      UserDefaults.standard.removeObject(forKey: "lastNickname")
      UserDefaults.standard.removeObject(forKey: "gameSite")
    }
  }

  var body: some Scene {
    WindowGroup {
      TabView {
        SearchView()
          .tabItem { Label("Games", systemImage: "magnifyingglass") }
        OpeningsView()
          .tabItem { Label("Openings", systemImage: "book") }
      }
    }
  }
}
