import XCTest

/// Design › Accessibility: the keyboard and the accessibility audit of the
/// Mac app (design log 004, Round 3).
@MainActor
final class FortkeepsScrollUITests: XCTestCase {
    let app = launched()

    /// The argument domain wins over the defaults a manual run left.
    static func launched() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES", "-ShowsFormatBar", "YES", "-ShowsStatusBar", "YES"
        ]
        return app
    }

    /// The app `open` starts outlives the test unless it is quit.
    override func tearDown() async throws {
        app.terminate()
        try await super.tearDown()
    }

    /// Opens new files in one folder, the way Finder opens them; returns the
    /// window of the first.
    func open(_ text: String, also others: [String] = []) throws -> XCUIElement {
        let folder = FileManager.default.temporaryDirectory.appending(path: "UITests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // `open` launches the app; after `launch` it would start a second one.
        for (index, text) in ([text] + others).enumerated() {
            let url = folder.appending(path: "\(index).md")
            try Data(text.utf8).write(to: url)
            app.open(url)
            // The window's accessibility title is the file name, then the folder.
            XCTAssertTrue(window("\(index).md").waitForExistence(timeout: 10))
        }
        XCTAssertFalse(app.windows["Fortkeeps Scroll"].exists)
        return window("0.md")
    }

    func window(_ name: String) -> XCUIElement {
        app.windows.element(matching: NSPredicate(format: "title BEGINSWITH %@", name))
    }

    func testTheEmptyWindowPassesTheAccessibilityAudit() throws {
        app.launch()
        XCTAssertTrue(app.buttons["Open…"].waitForExistence(timeout: 10))

        // A recent file's button reads the file name, which is the person's text, not ours.
        try app.performAccessibilityAudit { issue in
            issue.auditType == .sufficientElementDescription && issue.element?.title.hasSuffix(".md") == true
        }
    }

    func testTheDocumentWindowPassesTheAccessibilityAudit() throws {
        _ = try open("# Title\n\nSee [b](b.md) and ![map](map.png).\n\n- [ ] Book the room\n")

        try app.performAccessibilityAudit()
    }

    func testOptionCommandLLocksAndUnlocksTheText() throws {
        let text = try open("a\n").textViews.firstMatch
        text.click()

        app.typeKey("l", modifierFlags: [.command, .option])
        app.typeText("x")
        XCTAssertEqual(text.value as? String, "a\n")

        app.typeKey("l", modifierFlags: [.command, .option])
        app.typeText("x")
        XCTAssertNotEqual(text.value as? String, "a\n")
    }

    func testTabMovesToALinkAndReturnOpensIt() throws {
        let text = try open("See [b](b.md).\n").textViews.firstMatch
        text.click()
        app.typeKey("l", modifierFlags: [.command, .option])

        app.typeKey(.tab, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(app.popovers.staticTexts["“b.md” isn’t in this folder."].waitForExistence(timeout: 5))
    }

    func testShiftCommandWClosesEveryTab() throws {
        _ = try open("a\n", also: ["b\n"])

        app.typeKey("w", modifierFlags: [.command, .shift])

        XCTAssertTrue(app.windows["Fortkeeps Scroll"].waitForExistence(timeout: 10))
        XCTAssertFalse(window("0.md").exists)
        XCTAssertFalse(window("1.md").exists)
    }

    func testControlF6MovesIntoTheFormatBarAndEscGoesBack() throws {
        let text = try open("word\n").textViews.firstMatch
        text.click()
        app.typeKey("a", modifierFlags: .command)

        app.typeKey(.F6, modifierFlags: .control)
        app.typeKey(.space, modifierFlags: [])
        XCTAssertEqual(text.value as? String, "**word**\n")

        app.typeKey(.escape, modifierFlags: [])
        app.typeText("!")
        XCTAssertTrue((text.value as? String)?.contains("!") == true)
    }

    /// The manual check of plan 02 stage 2c: a CRLF file stays as it is
    /// until a change; a checkbox click saves LF text at once, and so does
    /// its Undo.
    func testACRLFFileKeepsItsBytesAndACheckboxAndItsUndoSaveAtOnce() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "UITests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "crlf.md")
        let original = Data("- [ ] one\r\n- [ ] two\r\n".utf8)
        try original.write(to: url)
        func saved(_ text: String) -> Bool {
            let deadline = Date().addingTimeInterval(5)
            while Date() < deadline {
                if (try? Data(contentsOf: url)) == Data(text.utf8) {
                    return true
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
            return false
        }

        app.open(url)
        XCTAssertTrue(window("crlf.md").waitForExistence(timeout: 10))
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        XCTAssertEqual(try Data(contentsOf: url), original)

        app.open(url)
        XCTAssertTrue(window("crlf.md").waitForExistence(timeout: 10))
        // The caret leaves the first line, so its checkbox is drawn: centered at 63, 88 from the window's corner.
        app.typeKey(.downArrow, modifierFlags: .command)
        window("crlf.md").coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 63, dy: 88)).click()
        XCTAssertTrue(saved("- [x] one\n- [ ] two\n"))

        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(saved("- [ ] one\n- [ ] two\n"))
    }
}
