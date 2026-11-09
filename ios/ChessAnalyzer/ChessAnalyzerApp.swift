import SwiftUI

@main
struct ChessAnalyzerApp: App {
  init() {
    // UI tests start from a clean slate rather than the last nickname searched.
    if CommandLine.arguments.contains("-resetForUITests") {
      UserDefaults.standard.removeObject(forKey: "lastNickname")
    }
  }

  var body: some Scene {
    WindowGroup {
      SearchView()
    }
  }
}
