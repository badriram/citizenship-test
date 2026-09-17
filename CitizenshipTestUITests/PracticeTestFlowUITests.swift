import XCTest

/// End-to-end coverage of the paths that only break when the app is actually driven.
/// The results screen shipped once with no visible way out; a test that finishes a
/// test and looks for the exit would have caught it.
final class PracticeTestFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Results screen has a visible way home

    func testFinishingATestOffersAVisibleWayBackHome() throws {
        // SwiftUI composes a row's label from every text in it, so match on a
        // prefix rather than the visible title alone.
        button(labelBeginsWith: "Practice Test").tap()

        XCTAssertTrue(answerField.waitForExistence(timeout: 15),
                      "practice test did not present an answer field")

        // Walk the whole test. The answer text is irrelevant — this asserts the
        // navigation contract, not grading.
        for _ in 0..<(20 - 1) {
            typeAnswer("the constitution")
            button(labelBeginsWith: "Next").tap()
        }
        typeAnswer("the constitution")

        let submit = button(labelBeginsWith: "Submit Test")
        XCTAssertTrue(submit.waitForExistence(timeout: 10), "no Submit Test button on the last question")
        submit.tap()

        // Grading may run on-device, so allow generous time before results render.
        let retake = button(labelBeginsWith: "Take Another Test")
        XCTAssertTrue(retake.waitForExistence(timeout: 180), "results screen never appeared")

        // The regression: an explicit, labelled exit — not just the system chevron.
        let home = button(labelBeginsWith: "Back to Home")
        XCTAssertTrue(home.exists,
                      "results screen has no visible way back to the home screen")

        home.tap()
        XCTAssertTrue(button(labelBeginsWith: "Study Flashcards").waitForExistence(timeout: 15),
                      "Back to Home did not return to the home screen")
    }

    // MARK: - State can be set without location

    func testStateCanBeChosenWithoutSharingLocation() throws {
        app.buttons["Your Location & Officials"].firstMatch.tap()

        // A previous run may have left a state set, in which case the card shows the
        // compact display. Clear it so the no-location path is what gets asserted.
        let change = button(labelBeginsWith: "Change Location")
        if change.waitForExistence(timeout: 3) {
            change.tap()
        }

        XCTAssertTrue(app.staticTexts["Pick your state"].firstMatch.waitForExistence(timeout: 5),
                      "no manual state picker — a user who declines location cannot answer state questions")
    }

    // MARK: - Helpers

    private func button(labelBeginsWith prefix: String) -> XCUIElement {
        app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
            .firstMatch
    }

    /// The answer field is a vertical-axis TextField, which surfaces as a text view
    /// on some runtimes and a text field on others.
    private var answerField: XCUIElement {
        app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
    }

    private func typeAnswer(_ text: String) {
        let field = answerField
        guard field.waitForExistence(timeout: 10) else {
            XCTFail("answer field never appeared")
            return
        }
        field.tap()
        field.typeText(text)
    }
}
