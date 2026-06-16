import XCTest

/// End-to-end UI test for the note lifecycle: create a wound, add a note, edit
/// it (text + confirm the time is editable), then delete it.
final class NoteFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["HEALIFY_NO_HEALTH"] = "1"   // skip the Health prompt
        app.launchEnvironment["HEALIFY_UITEST"] = "1"      // clean in-memory store
        app.launch()
        return app
    }

    /// The note text field is an axis-vertical TextField, which may surface as a
    /// text view or a text field depending on OS — poll for either.
    private func noteField(_ app: XCUIApplication, timeout: TimeInterval = 5) -> XCUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.textViews["noteText"].exists { return app.textViews["noteText"] }
            if app.textFields["noteText"].exists { return app.textFields["noteText"] }
            usleep(100_000)
        }
        return app.textFields["noteText"]
    }

    func testAddEditDeleteNote() {
        let app = launch()

        // 1. Create a wound (name only — no body-map tap needed).
        //    Generous first wait: cold CI runners are slow to boot + render.
        let addMenu = app.buttons["addMenu"].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 30), "App should launch to the dashboard")
        addMenu.tap()
        app.buttons["One wound"].tap()
        let name = app.textFields["woundName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "New-wound form should appear")
        name.tap()
        name.typeText("UITest wound")
        app.buttons["Save"].tap()

        // 2. Lands on the wound timeline; add a note.
        let addNote = app.buttons["Add Note"]
        XCTAssertTrue(addNote.waitForExistence(timeout: 5), "Should navigate to the wound and show Add Note")
        addNote.tap()

        let field = noteField(app)
        XCTAssertTrue(field.exists, "Note text field should appear")
        field.tap()
        field.typeText("first note")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["first note"].waitForExistence(timeout: 5), "Note should appear in the timeline")

        // 3. Tap the note to edit: the editor opens, loads the existing text,
        //    and exposes the time for editing.
        app.staticTexts["first note"].tap()
        XCTAssertTrue(app.navigationBars["Edit Note"].waitForExistence(timeout: 5), "Edit Note screen should open")
        XCTAssertTrue(app.datePickers.firstMatch.exists, "The note's time should be editable")
        XCTAssertEqual(noteField(app).value as? String, "first note", "Editor should load the existing note text")

        // 4. Delete from the editor. The destructive button is at the bottom of
        //    a long form, which SwiftUI renders lazily — scroll it into view.
        let deleteButton = app.buttons["Delete Note"]
        var attempts = 0
        while !deleteButton.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(deleteButton.isHittable, "Delete button should be reachable")
        deleteButton.tap()
        let confirm = app.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Delete confirmation should appear")
        confirm.tap()
        XCTAssertTrue(app.staticTexts["first note"].waitForNonExistence(timeout: 5), "Note should be gone")
    }
}
