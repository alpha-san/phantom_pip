import XCTest
import AppKit
@testable import PhantomPiP

final class AppIconTests: XCTestCase {

    func testExportWritesDecodablePNGOfRequestedSize() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("phantompip-icon-\(UUID().uuidString).png").path
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertTrue(AppIcon.export(to: path, pixels: 64))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(rep.pixelsWide, 64)
        XCTAssertEqual(rep.pixelsHigh, 64)
    }
}
