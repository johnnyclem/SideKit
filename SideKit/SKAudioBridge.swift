import Foundation

/// Swift face of the C++ `SideKitAudio` static library.
/// Owns the engine handle and posts params from the main thread.
final class SKAudioBridge {
    static let shared = SKAudioBridge()

    let version: String
    private let engine: OpaquePointer

    private init() {
        version = String(cString: sk_engine_version())
        guard let handle = sk_engine_create(48_000, 2) else {
            fatalError("SideKitAudio: sk_engine_create failed")
        }
        engine = handle
    }

    deinit {
        sk_engine_destroy(engine)
    }

    /// Fill an interleaved stereo buffer. Safe to call from the audio thread.
    @discardableResult
    func render(into buffer: UnsafeMutablePointer<Float>, frames: UInt32) -> UInt32 {
        sk_engine_render(engine, buffer, frames)
    }

    func lastInfo() -> SKRenderInfo {
        sk_engine_last_info(engine)
    }

    func setTestTone(enabled: Bool, hz: Float = 440) {
        sk_engine_set_test_tone(engine, enabled ? 1 : 0, hz)
        sk_engine_set_output_gain(engine, enabled ? 0.18 : 0)
    }

    /// Offline warmup used at launch so we know the lib actually linked.
    func warmup() -> SKRenderInfo {
        var scratch = [Float](repeating: 0, count: 64 * 2)
        scratch.withUnsafeMutableBufferPointer { ptr in
            _ = sk_engine_render(engine, ptr.baseAddress, 64)
        }
        return sk_engine_last_info(engine)
    }
}
