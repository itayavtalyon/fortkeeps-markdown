import XCTest

/// The iOS must-pass checks of plan 02, stage 2d: New, the iPhone back
/// button, the iPad tab, and the accessibility audit of the document screen.
@MainActor
final class FortkeepsScrollIOSUITests: XCTestCase {
    private let app = launched()
    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// The app starts from no files.
    static func launched() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FK_SCROLL_UI_TEST"] = "1"
        return app
    }

    override func tearDown() async throws {
        app.terminate()
        try await super.tearDown()
    }

    /// New file on iPhone: `Untitled.md` in the app's folder, the keyboard up,
    /// and a back button to `Open Files`, whose Open section lists it.
    func testIPhoneNewFileOpensUntitledAndGoesBackToOpenFiles() throws {
        try XCTSkipIf(isPad, "iPhone only")
        app.launch()
        XCTAssert(app.staticTexts["Files you open will show up here."].waitForExistence(timeout: 10))

        app.toolbars.buttons["New file"].tap()

        XCTAssert(app.navigationBars["Untitled.md"].waitForExistence(timeout: 10))
        XCTAssert(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        let back = app.navigationBars["Untitled.md"].buttons["Open Files"]
        XCTAssert(back.exists)
        back.tap()
        XCTAssert(app.cells.staticTexts["Untitled.md"].waitForExistence(timeout: 10))
        XCTAssert(app.staticTexts["Open"].exists)
    }

    /// New in the iPad document browser opens a tab with the file name and
    /// a close control labelled "Close {name}".
    func testIPadNewOpensATabWithItsCloseControl() throws {
        try XCTSkipUnless(isPad, "iPad only")
        app.launch()

        createInBrowser()

        let close = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Close Untitled'")).firstMatch
        XCTAssert(close.waitForExistence(timeout: 15), app.debugDescription)
        let name = close.label.replacingOccurrences(of: "Close ", with: "")
        XCTAssert(name.hasPrefix("Untitled") && name.hasSuffix(".md"))
        XCTAssert(app.buttons[name].exists)
        close.tap()
        XCTAssert(app.buttons["Create Document"].waitForExistence(timeout: 10))
    }

    /// The app starts the browser in its folder, On My iPad › FK Scroll,
    /// where New creates; Recents has no folder to create in.
    private func createInBrowser() {
        let create = app.buttons["FullDocumentManagerViewControllerNavigationBarCreateButtonIdentifier"]
        XCTAssert(app.staticTexts["UI test"].waitForExistence(timeout: 10))
        XCTAssert(create.waitForExistence(timeout: 10))
        create.tap()
    }

    /// The document screen with a heading, a checkbox, and a link.
    func testTheDocumentScreenPassesTheAccessibilityAudit() throws {
        app.launch()
        if isPad {
            createInBrowser()
        } else {
            app.toolbars.buttons["New file"].tap()
        }
        XCTAssert(app.keyboards.firstMatch.waitForExistence(timeout: 15))
        app.typeText("# Trip\n\nSee [the map](https://example.com).\n\n- [ ] Book the room")

        // The title is the file name, which is the person's text, not ours.
        try app.performAccessibilityAudit { issue in
            issue.auditType == .sufficientElementDescription && issue.element?.label.hasSuffix(".md") == true
        }
    }
}
