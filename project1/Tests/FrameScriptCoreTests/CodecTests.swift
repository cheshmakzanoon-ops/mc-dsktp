import XCTest
@testable import FrameScriptCore

final class CodecTests: XCTestCase {
    func testFountainRoundTripKeepsCoreElementTypes() {
        let source = """
        INT. APARTMENT — NIGHT

        LENA
        Are you still there?

        CUT TO:
        """
        let parsed = FountainCodec.parse(source)
        XCTAssertEqual(parsed.map(\.type), [.sceneHeading, .character, .dialogue, .transition])
        let reparsed = FountainCodec.parse(FountainCodec.serialize(parsed))
        XCTAssertEqual(reparsed.map(\.type), parsed.map(\.type))
        XCTAssertEqual(reparsed.map(\.text), parsed.map(\.text))
    }

    func testFountainMetadataIsReadWithoutBecomingScriptAction() {
        let source = """
        Title: North Point
        Author: A. Writer

        INT. LIGHTHOUSE — NIGHT

        CUT TO:
        """
        let decoded = FountainCodec.decode(source)
        XCTAssertEqual(decoded.title, "North Point")
        XCTAssertEqual(decoded.author, "A. Writer")
        XCTAssertEqual(decoded.elements.map(\.type), [.sceneHeading, .transition])
    }

    func testFDXRoundTripEscapesMarkupAndRetainsMetadata() throws {
        let snapshot = ScreenplaySnapshot(
            title: "Rain & Glass",
            author: "A < Writer",
            contact: "writer@example.com",
            elements: [
                ScriptElement(type: .sceneHeading, text: "INT. STATION — NIGHT"),
                ScriptElement(type: .dialogue, text: "Wait for me & stay.")
            ]
        )
        let decoded = try FDXCodec.decode(FDXCodec.encode(snapshot))
        XCTAssertEqual(decoded.title, snapshot.title)
        XCTAssertEqual(decoded.author, snapshot.author)
        XCTAssertEqual(decoded.contact, snapshot.contact)
        XCTAssertEqual(decoded.elements.map(\.type), snapshot.elements.map(\.type))
        XCTAssertEqual(decoded.elements.map(\.text), snapshot.elements.map(\.text))
    }
}
