import XCTest
@testable import PhantomPiP

final class HistoryStoreTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("phantompip-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testAddCreatesEntry() {
        let store = HistoryStore(directory: dir)
        store.add(url: "https://youtu.be/aaa")
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.url, "https://youtu.be/aaa")
    }

    func testEmptyAndWhitespaceURLsIgnored() {
        let store = HistoryStore(directory: dir)
        store.add(url: "")
        store.add(url: "   \n ")
        XCTAssertTrue(store.items.isEmpty)
    }

    func testURLIsTrimmed() {
        let store = HistoryStore(directory: dir)
        store.add(url: "  https://youtu.be/aaa  ")
        XCTAssertEqual(store.items.first?.url, "https://youtu.be/aaa")
    }

    func testDuplicateMovesToTopWithoutDuplicating() {
        let store = HistoryStore(directory: dir)
        store.add(url: "a")
        store.add(url: "b")
        store.add(url: "a") // re-watch a
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.map(\.url), ["a", "b"])
    }

    func testReWatchKeepsExistingTitle() {
        let store = HistoryStore(directory: dir)
        store.add(url: "a")
        store.setTitle(for: "a", title: "My Video")
        store.add(url: "a")
        XCTAssertEqual(store.items.first?.title, "My Video")
    }

    func testMaxItemsCapKeepsNewest() {
        let store = HistoryStore(directory: dir, maxItems: 3)
        for u in ["a", "b", "c", "d", "e"] { store.add(url: u) }
        XCTAssertEqual(store.items.map(\.url), ["e", "d", "c"])
    }

    func testSetTitleUnknownURLIsNoop() {
        let store = HistoryStore(directory: dir)
        store.add(url: "a")
        store.setTitle(for: "does-not-exist", title: "X")
        XCTAssertNil(store.items.first?.title)
    }

    func testSetTitleEmptyIsIgnored() {
        let store = HistoryStore(directory: dir)
        store.add(url: "a")
        store.setTitle(for: "a", title: "   ")
        XCTAssertNil(store.items.first?.title)
    }

    func testPersistenceRoundTrip() {
        let store1 = HistoryStore(directory: dir)
        store1.add(url: "a")
        store1.add(url: "b")
        store1.setTitle(for: "b", title: "Bee")

        let store2 = HistoryStore(directory: dir)
        XCTAssertEqual(store2.items.map(\.url), ["b", "a"])
        XCTAssertEqual(store2.items.first?.title, "Bee")
    }

    func testClearEmptiesAndPersists() {
        let store1 = HistoryStore(directory: dir)
        store1.add(url: "a")
        store1.clear()
        XCTAssertTrue(store1.items.isEmpty)

        let store2 = HistoryStore(directory: dir)
        XCTAssertTrue(store2.items.isEmpty)
    }
}
