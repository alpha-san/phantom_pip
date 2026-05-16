import XCTest
@testable import PhantomPiP

final class HistoryEntryTests: XCTestCase {

    private func entry(url: String, title: String?) -> HistoryEntry {
        HistoryEntry(url: url, title: title, lastWatched: Date())
    }

    func testTitlePreferredWhenPresent() {
        XCTAssertEqual(entry(url: "https://x.com", title: "Hello").displayTitle, "Hello")
    }

    func testStripsSchemeAndWWW() {
        XCTAssertEqual(
            entry(url: "https://www.youtube.com/watch?v=abc", title: nil).displayTitle,
            "youtube.com/watch?v=abc")
        XCTAssertEqual(
            entry(url: "http://www.example.com/p", title: nil).displayTitle,
            "example.com/p")
    }

    func testStripsBareWWW() {
        XCTAssertEqual(entry(url: "www.example.com", title: nil).displayTitle,
                       "example.com")
    }

    func testWhitespaceOnlyTitleFallsBackToURL() {
        XCTAssertEqual(entry(url: "https://example.com", title: "   ").displayTitle,
                       "example.com")
    }

    func testLongTitleIsTruncatedWithEllipsis() {
        let long = String(repeating: "x", count: 100)
        let shown = entry(url: "https://x.com", title: long).displayTitle
        XCTAssertEqual(shown.count, 64)
        XCTAssertTrue(shown.hasSuffix("…"))
    }

    func testLongURLIsTruncatedWithEllipsis() {
        let long = "https://example.com/" + String(repeating: "a", count: 100)
        let shown = entry(url: long, title: nil).displayTitle
        XCTAssertEqual(shown.count, 64)
        XCTAssertTrue(shown.hasSuffix("…"))
    }
}
