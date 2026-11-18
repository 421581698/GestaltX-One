import XCTest
@testable import GestaltXOneCore

final class PlistEditorTests: XCTestCase {
    private let editor = PlistEditor()

    private func source() throws -> Data {
        try editor.encode(.dictionary([
            "ProductType": .string("iPhone18,2"),
            "Display": .dictionary([
                "AlwaysOn": .boolean(false),
                "Brightness": .real(0.75)
            ]),
            "Counter": .integer(7)
        ]))
    }

    func testPreviewProducesDiffAndRequiresMatchingConfirmation() throws {
        let original = try source()
        let plan = try editor.preview(original, edits: [
            .set(.boolean(true), at: ["Display", "AlwaysOn"]),
            .set(.integer(8), at: ["Counter"])
        ])
        XCTAssertEqual(plan.changes.count, 2)
        XCTAssertEqual(plan.changes[0].previousValue, .boolean(false))
        XCTAssertEqual(plan.changes[0].proposedValue, .boolean(true))
        XCTAssertThrowsError(try editor.applyPreview(
            plan,
            to: original,
            confirmationToken: "wrong-token"
        ))
        let output = try editor.applyPreview(
            plan,
            to: original,
            confirmationToken: plan.confirmationToken
        )
        let decoded = try editor.decode(output)
        guard case .dictionary(let root) = decoded,
              case .dictionary(let display)? = root["Display"] else {
            return XCTFail("Expected dictionary plist")
        }
        XCTAssertEqual(display["AlwaysOn"], .boolean(true))
        XCTAssertEqual(root["Counter"], .integer(8))
    }

    func testStaleSourceCannotApplyAPlan() throws {
        let original = try source()
        let plan = try editor.preview(original, edits: [
            .set(.boolean(true), at: ["Display", "AlwaysOn"])
        ])
        let changedSource = try editor.encode(.dictionary(["Counter": .integer(9)]))
        XCTAssertThrowsError(try editor.applyPreview(
            plan,
            to: changedSource,
            confirmationToken: plan.confirmationToken
        )) { error in
            XCTAssertEqual(error as? PlistEditorError, .sourceChanged)
        }
    }

    func testRemoveAndMissingKeyHandling() throws {
        let original = try source()
        let plan = try editor.preview(original, edits: [.remove(at: ["Counter"])])
        let output = try editor.applyPreview(
            plan,
            to: original,
            confirmationToken: plan.confirmationToken
        )
        guard case .dictionary(let values) = try editor.decode(output) else {
            return XCTFail("Expected dictionary root")
        }
        XCTAssertNil(values["Counter"])
        XCTAssertThrowsError(try editor.preview(original, edits: [.remove(at: ["Missing"])]))
    }

    func testRejectsDuplicateAndEmptyPaths() throws {
        let original = try source()
        XCTAssertThrowsError(try editor.preview(original, edits: [
            .set(.integer(1), at: ["Counter"]),
            .set(.integer(2), at: ["Counter"])
        ]))
        XCTAssertThrowsError(try editor.preview(original, edits: [.remove(at: [])]))
    }

    func testRejectsNonDictionaryRootAndMalformedInput() throws {
        let arrayData = try PropertyListSerialization.data(
            fromPropertyList: ["one", "two"],
            format: .xml,
            options: 0
        )
        XCTAssertThrowsError(try editor.decode(arrayData))
        XCTAssertThrowsError(try editor.decode(Data("not a plist".utf8)))
    }
}
