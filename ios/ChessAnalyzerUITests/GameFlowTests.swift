import XCTest

/// Walks the real app against live chess.com: search, open a game, step, stats.
final class GameFlowTests: XCTestCase {
  @MainActor
  func testSearchOpenStepAndStats() throws {
    let app = launchWithEmptyNickname()

    let field = app.textFields["Chess.com nickname"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText("hikaru")
    app.buttons["Find games"].tap()

    // Rows read as "Win, vs Opponent (3,089), Black, ...".
    let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS ', vs '"))
    let firstGame = rows.firstMatch
    XCTAssertTrue(firstGame.waitForExistence(timeout: 20), "no games loaded")
    XCTAssertEqual(rows.count, 5)
    XCTAssertFalse(app.keyboards.element.exists, "keyboard should close after searching")
    snapshot(app, "1-search")

    let loadMore = app.buttons["Load 5 more"]
    app.swipeUp()
    XCTAssertTrue(loadMore.waitForExistence(timeout: 5))
    loadMore.tap()
    app.swipeDown()
    XCTAssertTrue(
      app.staticTexts["Latest 10 games"].waitForExistence(timeout: 20), "second page didn't load")
    snapshot(app, "1b-more")

    firstGame.tap()
    let next = app.buttons["Next move"]
    XCTAssertTrue(next.waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Previous move"].isEnabled)
    snapshot(app, "2-board-start")

    let current = app.staticTexts["currentMove"]
    XCTAssertEqual(current.label, "Start")
    for _ in 0..<4 { next.tap() }
    XCTAssertTrue(current.label.hasPrefix("2... "), current.label)
    app.buttons["Previous move"].tap()
    XCTAssertTrue(current.label.hasPrefix("2. "), current.label)
    snapshot(app, "3-board-move3")

    app.buttons["End"].tap()
    XCTAssertFalse(next.isEnabled)
    snapshot(app, "4-board-end")

    app.buttons["Stats"].tap()
    XCTAssertTrue(app.staticTexts["Opening choice"].firstMatch.waitForExistence(timeout: 5))
    snapshot(app, "5-stats")
  }

  @MainActor
  func testLichessGames() {
    let app = launchWithEmptyNickname()
    app.buttons["Lichess"].tap()
    let field = app.textFields["Lichess username"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText("DrNykterstein")
    app.buttons["Find games"].tap()

    let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS ', vs '"))
    XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 20), "no games loaded")
    XCTAssertEqual(rows.count, 5)
    snapshot(app, "12-lichess-search")

    rows.firstMatch.tap()
    let next = app.buttons["Next move"]
    XCTAssertTrue(next.waitForExistence(timeout: 5))
    next.tap()
    XCTAssertTrue(app.staticTexts["currentMove"].label.hasPrefix("1. "))
    app.buttons["Stats"].tap()
    XCTAssertTrue(app.staticTexts["Opening choice"].firstMatch.waitForExistence(timeout: 5))
    snapshot(app, "13-lichess-stats")
  }

  @MainActor
  func testReviewGameWithStockfish() throws {
    let app = launchWithEmptyNickname(extra: ["-reviewDepth", "6"])
    let field = app.textFields["Chess.com nickname"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText("hikaru")
    app.buttons["Find games"].tap()
    let firstGame = app.buttons.matching(NSPredicate(format: "label CONTAINS ', vs '")).firstMatch
    XCTAssertTrue(firstGame.waitForExistence(timeout: 20), "no games loaded")
    firstGame.tap()

    let review = app.buttons["Review game"]
    XCTAssertTrue(review.waitForExistence(timeout: 5))
    review.tap()
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Analyzing'")).firstMatch.waitForExistence(timeout: 10))
    snapshot(app, "9-review-running")

    let reviewTab = app.buttons["Review"]
    XCTAssertTrue(reviewTab.waitForExistence(timeout: 180), "review didn't finish")
    XCTAssertTrue(app.otherElements["Evaluation"].exists || app.descendants(matching: .any)["Evaluation"].exists)
    for _ in 0..<6 { app.buttons["Next move"].tap() }
    XCTAssertTrue(app.descendants(matching: .any)["moveVerdict"].exists)
    snapshot(app, "10-review-board")

    reviewTab.tap()
    XCTAssertTrue(app.staticTexts["Accuracy"].waitForExistence(timeout: 5))
    snapshot(app, "11-review-summary")
  }

  @MainActor
  func testUnknownPlayerShowsMessage() {
    let app = launchWithEmptyNickname()
    let field = app.textFields["Chess.com nickname"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText("this-user-should-not-exist-zz9")
    app.buttons["Find games"].tap()
    let message = app.staticTexts["No chess.com player named this-user-should-not-exist-zz9."]
    XCTAssertTrue(message.waitForExistence(timeout: 20))
    snapshot(app, "6-unknown")
  }

  @MainActor
  func testOpeningsTabStepsThroughALine() {
    let app = launchWithEmptyNickname()
    app.tabBars.buttons["Openings"].tap()
    let italian = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Italian Game'"))
    XCTAssertTrue(italian.firstMatch.waitForExistence(timeout: 5))
    italian.firstMatch.tap()

    let current = app.staticTexts["currentMove"]
    XCTAssertTrue(current.waitForExistence(timeout: 5))
    XCTAssertEqual(current.label, "Start")
    app.buttons["End"].tap()
    XCTAssertEqual(current.label, "3. Bc4")
    snapshot(app, "7-opening")

    // A variation starts where it branches, so the next move is its first new one.
    app.buttons["Two Knights Defense"].tap()
    XCTAssertEqual(current.label, "3. Bc4")
    app.buttons["Next move"].tap()
    XCTAssertEqual(current.label, "3... Nf6")
    snapshot(app, "8-variation")
  }

  /// The app remembers the last nickname, so ask it to forget.
  @MainActor
  private func launchWithEmptyNickname(extra: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += ["-resetForUITests"] + extra
    app.launch()
    return app
  }

  @MainActor
  private func snapshot(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
