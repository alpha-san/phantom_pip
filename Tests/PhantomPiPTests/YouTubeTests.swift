import XCTest
@testable import PhantomPiP

final class YouTubeTests: XCTestCase {

    func testWatchURL() {
        XCTAssertEqual(YouTube.id(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                       "dQw4w9WgXcQ")
    }

    func testWatchURLWithExtraParams() {
        XCTAssertEqual(
            YouTube.id(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s&list=PL"),
            "dQw4w9WgXcQ")
    }

    func testShortURL() {
        XCTAssertEqual(YouTube.id(from: "https://youtu.be/dQw4w9WgXcQ"),
                       "dQw4w9WgXcQ")
    }

    func testShortURLWithQuery() {
        XCTAssertEqual(YouTube.id(from: "https://youtu.be/dQw4w9WgXcQ?t=10"),
                       "dQw4w9WgXcQ")
    }

    func testShorts() {
        XCTAssertEqual(YouTube.id(from: "https://www.youtube.com/shorts/abc123_-XYZ"),
                       "abc123_-XYZ")
    }

    func testEmbed() {
        XCTAssertEqual(YouTube.id(from: "https://www.youtube.com/embed/dQw4w9WgXcQ"),
                       "dQw4w9WgXcQ")
    }

    func testLive() {
        XCTAssertEqual(YouTube.id(from: "https://www.youtube.com/live/dQw4w9WgXcQ"),
                       "dQw4w9WgXcQ")
    }

    func testNoSchemeIsNormalized() {
        XCTAssertEqual(YouTube.id(from: "youtube.com/watch?v=dQw4w9WgXcQ"),
                       "dQw4w9WgXcQ")
    }

    func testMobileHost() {
        XCTAssertEqual(YouTube.id(from: "https://m.youtube.com/watch?v=dQw4w9WgXcQ"),
                       "dQw4w9WgXcQ")
    }

    func testNonYouTubeReturnsNil() {
        XCTAssertNil(YouTube.id(from: "https://vimeo.com/123456"))
        XCTAssertNil(YouTube.id(from: "https://example.com/watch?v=abc"))
    }

    func testMissingIDReturnsNil() {
        XCTAssertNil(YouTube.id(from: "https://www.youtube.com/watch"))
        XCTAssertNil(YouTube.id(from: "https://www.youtube.com/feed/subscriptions"))
    }

    func testImplausibleIDReturnsNil() {
        // A spaced / punctuated "id" is rejected by the character check.
        XCTAssertNil(YouTube.id(from: "https://www.youtube.com/watch?v=not a real id!"))
    }

    func testGarbageReturnsNil() {
        XCTAssertNil(YouTube.id(from: ""))
        XCTAssertNil(YouTube.id(from: "not a url"))
    }
}
