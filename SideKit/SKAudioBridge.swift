import Foundation

/// Swift face of the C++ `SideKitAudio` static library.
/// Owns the engine handle. UI thread posts; audio thread renders.
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

    @discardableResult
    func render(into buffer: UnsafeMutablePointer<Float>, frames: UInt32) -> UInt32 {
        sk_engine_render(engine, buffer, frames)
    }

    func lastInfo() -> SKRenderInfo {
        sk_engine_last_info(engine)
    }

    func setMaster(_ linear: Float) {
        sk_engine_set_master(engine, linear)
    }

    func setCrossfader(_ xf: Float) {
        sk_engine_set_crossfader(engine, xf)
    }

    func setChannelMix(ch: UInt32, gainDb: Float, fader: Float, mute: Bool) {
        sk_engine_set_channel_mix(engine, ch, gainDb, fader, mute ? 1 : 0)
    }

    func setChannelEQ(ch: UInt32, lo: Float, mid: Float, hi: Float, styleMul: Float) {
        sk_engine_set_channel_eq(engine, ch, lo, mid, hi, styleMul)
    }

    func setTransport(ch: UInt32, playing: Bool, pattern: UInt32, bpm: Float) {
        sk_engine_set_transport(engine, ch, playing ? 1 : 0, pattern, bpm)
    }

    func setTestTone(enabled: Bool, hz: Float = 440) {
        sk_engine_set_test_tone(engine, enabled ? 1 : 0, hz)
        sk_engine_set_output_gain(engine, enabled ? 0.18 : 0)
    }

    @discardableResult
    func loadClip(ch: UInt32, pcm: UnsafePointer<Float>, frames: UInt32, channels: UInt32) -> Bool {
        sk_engine_load_clip(engine, ch, pcm, frames, channels) == 1
    }

    func clearClip(ch: UInt32) {
        sk_engine_clear_clip(engine, ch)
    }

    func clipInfo(ch: UInt32) -> SKClipInfo {
        sk_engine_clip_info(engine, ch)
    }

    func setClipPosition(ch: UInt32, normalized: Float) {
        sk_engine_set_clip_position(engine, ch, normalized)
    }

    func warmup() -> SKRenderInfo {
        var scratch = [Float](repeating: 0, count: 64 * 2)
        scratch.withUnsafeMutableBufferPointer { ptr in
            _ = sk_engine_render(engine, ptr.baseAddress, 64)
        }
        return sk_engine_last_info(engine)
    }
}
