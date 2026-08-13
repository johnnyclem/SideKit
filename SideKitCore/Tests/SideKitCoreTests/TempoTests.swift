import XCTest
@testable import SideKitCore

final class TempoTests: XCTestCase {
    func testEqualPowerCrossfadeCenterIsEqual() {
        let (a, b) = Tempo.equalPowerCrossfade(0.5)
        XCTAssertEqual(a, b, accuracy: 1e-9)
        XCTAssertEqual(a * a + b * b, 1, accuracy: 1e-9)
    }

    func testEqualPowerCrossfadeEndpoints() {
        let fullA = Tempo.equalPowerCrossfade(0)
        XCTAssertEqual(fullA.a, 1, accuracy: 1e-9)
        XCTAssertEqual(fullA.b, 0, accuracy: 1e-9)
        let fullB = Tempo.equalPowerCrossfade(1)
        XCTAssertEqual(fullB.a, 0, accuracy: 1e-9)
        XCTAssertEqual(fullB.b, 1, accuracy: 1e-9)
    }

    func testEqualPowerCrossfadeClampsOutOfRange() {
        let low = Tempo.equalPowerCrossfade(-1)
        let high = Tempo.equalPowerCrossfade(2)
        XCTAssertEqual(low.a, 1, accuracy: 1e-9)
        XCTAssertEqual(high.b, 1, accuracy: 1e-9)
    }

    func testEffectiveBpm() {
        XCTAssertEqual(Tempo.effectiveBpm(120, pitchPercent: 8), 129.6, accuracy: 1e-9)
        XCTAssertEqual(Tempo.effectiveBpm(120, pitchPercent: -8), 110.4, accuracy: 1e-9)
        XCTAssertEqual(Tempo.effectiveBpm(120, pitchPercent: 0), 120)
    }

    func testBeatsToSeconds() {
        XCTAssertEqual(Tempo.beatsToSeconds(4, bpm: 120), 2.0, accuracy: 1e-9)
        XCTAssertEqual(Tempo.beatsToSeconds(1, bpm: 60), 1.0, accuracy: 1e-9)
        XCTAssertEqual(Tempo.beatsToSeconds(4, bpm: 0), 0)
    }

    func testQuantizeSnapsToNearestBeat() {
        // 120 BPM -> beat length 0.5s
        XCTAssertEqual(Tempo.quantize(0.62, bpm: 120), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Tempo.quantize(0.80, bpm: 120), 1.0, accuracy: 1e-9)
        XCTAssertEqual(Tempo.quantize(1.3, bpm: 0), 1.3)
    }

    func testNearestAutoLoopLength() {
        XCTAssertEqual(Tempo.nearestAutoLoopLength(0.9), 1)
        XCTAssertEqual(Tempo.nearestAutoLoopLength(3), 2)
        XCTAssertEqual(Tempo.nearestAutoLoopLength(100), 32)
        XCTAssertEqual(Tempo.nearestAutoLoopLength(0.1), 0.25)
    }

    func testEstimateBpmFromRegularOnsets() {
        // 0.5s spacing == 120 BPM
        let onsets = (0..<12).map { Double($0) * 0.5 }
        XCTAssertEqual(Tempo.estimateBpm(onsetTimes: onsets), 120, accuracy: 0.5)
    }

    func testEstimateBpmReturnsNilForSparseOnsets() {
        XCTAssertNil(Tempo.estimateBpm(onsetTimes: [0, 1]))
    }
}
