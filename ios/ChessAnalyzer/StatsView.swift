import ChessCore
import SwiftUI

struct StatsView: View {
  let game: ChessGame
  let opening: OpeningSummary

  var body: some View {
    Form {
      Section {
        row("Name", opening.name)
        row("ECO", opening.eco)
      } header: {
        Text("Opening")
      } footer: {
        Text("\(game.site.name) names one opening per game. Crediting it to a player is an estimate: defenses go to Black, the rest to White.")
      }

      Section("White: \(game.white.username)") {
        row("First move", opening.whiteFirstMove)
        row("Opening choice", opening.whiteChoice)
      }

      Section("Black: \(game.black.username)") {
        row("First move", opening.blackFirstMove)
        row("Opening choice", opening.blackChoice)
      }

      if let accuracies = game.accuracies {
        Section("Accuracy") {
          row(game.white.username, accuracies.white.formatted(.number.precision(.fractionLength(1))) + "%")
          row(game.black.username, accuracies.black.formatted(.number.precision(.fractionLength(1))) + "%")
        }
      }

      Section("Game") {
        row("Result", game.pgnTag("Result"))
        row("Ending", game.pgnTag("Termination"))
        row("Time control", game.timeControlDescription)
        row("Rated", game.rated ? "Yes" : "No")
      }
    }
  }

  private func row(_ title: String, _ value: String?) -> some View {
    LabeledContent(title, value: value ?? "—")
  }
}
