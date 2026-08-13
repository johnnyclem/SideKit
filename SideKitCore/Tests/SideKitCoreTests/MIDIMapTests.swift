import XCTest
@testable import SideKitCore

final class MIDIMapTests: XCTestCase {
    func testScaleUnipolar() {
        let b = MIDIBinding(kind: .controlChange, channel: 0, number: 1, targetId: "ch1.fader")
        XCTAssertEqual(b.scale(0), 0, accuracy: 1e-9)
        XCTAssertEqual(b.scale(127), 1, accuracy: 1e-9)
        XCTAssertEqual(b.scale(64) > 0.49 && b.scale(64) < 0.51, true)
    }

    func testScaleBipolar() {
        let b = MIDIBinding(kind: .controlChange, channel: 0, number: 1, targetId: "ch1.gain", bipolar: true)
        XCTAssertEqual(b.scale(0), -1, accuracy: 1e-9)
        XCTAssertEqual(b.scale(127), 1, accuracy: 1e-9)
    }

    func testScaleClampsOutOfRangeRaw() {
        let b = MIDIBinding(kind: .controlChange, channel: 0, number: 1, targetId: "x")
        XCTAssertEqual(b.scale(-10), 0)
        XCTAssertEqual(b.scale(500), 1)
    }

    func testFactoryMapHasUniqueTargets() {
        let bindings = FactoryMIDIMap.bindings()
        XCTAssertFalse(bindings.isEmpty)
        let targets = Set(bindings.map(\.targetId))
        XCTAssertEqual(targets.count, bindings.count, "factory map must not bind two controls to the same target")
    }

    func testFactoryMapNumbersAreValidMIDIRange() {
        for binding in FactoryMIDIMap.bindings() {
            XCTAssertTrue((0...127).contains(binding.number))
            XCTAssertTrue((0...15).contains(binding.channel))
        }
    }
}
