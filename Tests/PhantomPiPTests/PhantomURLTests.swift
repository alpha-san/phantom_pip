import XCTest
@testable import PhantomPiP

final class PhantomURLTests: XCTestCase {

    private func target(_ s: String) -> String? {
        guard let url = URL(string: s) else { return nil }
        return PhantomURL.videoTarget(from: url)
    }

    func testQueryParamU() {
        let enc = "https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdQw4w9WgXcQ"
        XCTAssertEqual(target("phantompip://play?u=\(enc)"),
                       "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    func testQueryParamUrlAlias() {
        let enc = "https%3A%2F%2Fexample.com%2Fv"
        XCTAssertEqual(target("phantompip://play?url=\(enc)"), "https://example.com/v")
    }

    func testPathForm() {
        let enc = "https%3A%2F%2Fexample.com%2Fv"
        XCTAssertEqual(target("phantompip://play/\(enc)"), "https://example.com/v")
    }

    func testBareForm() {
        let enc = "https%3A%2F%2Fexample.com%2Fv"
        XCTAssertEqual(target("phantompip://\(enc)"), "https://example.com/v")
    }

    func testHTTPAllowed() {
        XCTAssertEqual(target("phantompip://play?u=http%3A%2F%2Fexample.com"),
                       "http://example.com")
    }

    func testWrongSchemeRejected() {
        XCTAssertNil(target("https://play?u=https%3A%2F%2Fexample.com"))
        XCTAssertNil(target("evil://play?u=https%3A%2F%2Fexample.com"))
    }

    func testNonHTTPTargetRejected() {
        // Don't let an external link make the app open file:// or javascript:.
        XCTAssertNil(target("phantompip://play?u=file%3A%2F%2F%2Fetc%2Fpasswd"))
        XCTAssertNil(target("phantompip://play?u=javascript%3Aalert(1)"))
    }

    func testEmptyOrMissingTargetRejected() {
        XCTAssertNil(target("phantompip://play"))
        XCTAssertNil(target("phantompip://play?u="))
    }

    func testPreservesQueryAndFragmentInTarget() {
        let enc = "https%3A%2F%2Fy.com%2Fwatch%3Fv%3Dabc%26t%3D30s%23frag"
        XCTAssertEqual(target("phantompip://play?u=\(enc)"),
                       "https://y.com/watch?v=abc&t=30s#frag")
    }
}
