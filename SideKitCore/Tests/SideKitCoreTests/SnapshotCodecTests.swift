import XCTest
@testable import SideKitCore

final class SnapshotCodecTests: XCTestCase {
    private func makeSnapshot(_ name: String, at t: TimeInterval) -> MixerSnapshot {
        MixerSnapshot(
            name: name, createdAt: t,
            ch1Gain: 0, ch1EqHi: 0, ch1EqMid: 0, ch1EqLo: 0, ch1Fader: 0.78,
            ch2Gain: 0, ch2EqHi: 0, ch2EqMid: 0, ch2EqLo: 0, ch2Fader: 0.78,
            crossfader: 0.5, master: 0.82, fx: "filter", fxDepth: 0.65
        )
    }

    func testUpsertAppendsNew() {
        let list = SnapshotList.upserting(makeSnapshot("A", at: 1), into: [])
        XCTAssertEqual(list.count, 1)
    }

    func testUpsertReplacesById() {
        let s = makeSnapshot("A", at: 1)
        var renamed = s
        renamed.name = "A2"
        let list = SnapshotList.upserting(renamed, into: [s])
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.name, "A2")
    }

    func testUpsertCapsAtMaxCountDroppingOldest() {
        var list: [MixerSnapshot] = []
        for i in 0..<(SnapshotList.maxCount + 3) {
            list = SnapshotList.upserting(makeSnapshot("S\(i)", at: TimeInterval(i)), into: list)
        }
        XCTAssertEqual(list.count, SnapshotList.maxCount)
        XCTAssertFalse(list.contains { $0.name == "S0" })
        XCTAssertTrue(list.contains { $0.name == "S\(SnapshotList.maxCount + 2)" })
    }

    func testRemoving() {
        let s = makeSnapshot("A", at: 1)
        let list = SnapshotList.removing(id: s.id, from: [s])
        XCTAssertTrue(list.isEmpty)
    }

    func testMovingReorders() {
        let a = makeSnapshot("A", at: 1)
        let b = makeSnapshot("B", at: 2)
        let c = makeSnapshot("C", at: 3)
        let moved = SnapshotList.moving(id: c.id, to: 0, in: [a, b, c])
        XCTAssertEqual(moved.map(\.name), ["C", "A", "B"])
    }

    func testEncodeDecodeRoundTrips() {
        let list = [makeSnapshot("A", at: 1), makeSnapshot("B", at: 2)]
        guard let data = SnapshotList.encode(list) else { return XCTFail("encode failed") }
        let decoded = SnapshotList.decode(data)
        XCTAssertEqual(decoded, list)
    }

    func testDecodeInvalidDataReturnsEmpty() {
        let decoded = SnapshotList.decode(Data([0x00, 0x01]))
        XCTAssertEqual(decoded, [])
    }
}
