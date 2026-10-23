import XCTest

final class ToriUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.vocab"].waitForExistence(timeout: 20), "tab bar never appeared (data failed to load?)")
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testTabsAndMoreSheet() {
        shot("01-home")
        for tab in ["vocab", "review", "grammar", "kanji"] {
            app.buttons["tab.\(tab)"].tap()
            XCTAssertTrue(app.buttons["tab.\(tab)"].isSelected, tab)
            shot("tab-\(tab)")
        }
        app.buttons["tab.more"].tap()
        XCTAssertTrue(app.buttons["more.settings"].waitForExistence(timeout: 5))
        shot("more-sheet")
        for dest in ["counters", "homophones", "verbForms", "settings"] {
            if !app.buttons["more.\(dest)"].exists { app.buttons["tab.more"].tap() }
            XCTAssertTrue(app.buttons["more.\(dest)"].waitForExistence(timeout: 5), dest)
            app.buttons["more.\(dest)"].tap()
            sleep(1)
            shot("screen-\(dest)")
        }
    }

    func testVocabSearchAndDetail() {
        app.buttons["tab.vocab"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("tabemasu")
        XCTAssertTrue(app.staticTexts["食べます"].waitForExistence(timeout: 5))
        shot("vocab-search")
        app.staticTexts["食べます"].firstMatch.tap()
        XCTAssertTrue(app.buttons["xmark"].waitForExistence(timeout: 5) || app.buttons.matching(identifier: "Đóng").firstMatch.waitForExistence(timeout: 5))
        shot("vocab-detail")
    }

    func testReviewSessionFlow() {
        app.buttons["tab.review"].tap()
        let start = app.buttons["review.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        shot("review-setup")
        start.tap()

        XCTAssertTrue(app.buttons["review.card"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["review.counter"].label, "1 / 20")
        shot("review-front")

        app.buttons["review.showAnswer"].tap()
        XCTAssertTrue(app.buttons["review.rate.3"].waitForExistence(timeout: 5))
        shot("review-back")

        app.buttons["review.rate.3"].tap()                   // Good: advances without requeue
        XCTAssertTrue(app.staticTexts["review.counter"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["review.counter"].label, "2 / 20")

        app.buttons["review.showAnswer"].tap()
        app.buttons["review.rate.1"].tap()                   // Again: requeues, queue grows to 21
        XCTAssertTrue(app.staticTexts["review.counter"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["review.counter"].label, "3 / 21")
    }

    func testThemeSwitchAndLanguage() {
        app.buttons["tab.more"].tap()
        app.buttons["more.settings"].tap()
        let midnight = app.buttons["settings.theme.midnight"]
        XCTAssertTrue(midnight.waitForExistence(timeout: 5))
        midnight.tap()
        sleep(1)
        XCTAssertTrue(midnight.isSelected)
        shot("settings-midnight")
        app.buttons["tab.vocab"].tap()
        sleep(1)
        shot("vocab-midnight")
    }
}
