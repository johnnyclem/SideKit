import AudioToolbox
import Foundation
import UniformTypeIdentifiers

struct DecodedClip {
    let pcm: [Float]
    let frames: UInt32
    let sourceSampleRate: Double
    let sourceChannels: UInt32
    let resampled: Bool

    var duration: Double { Double(frames) / 48_000 }
}

enum FileDecodeError: LocalizedError {
    case unsupportedCodec(String)
    case empty
    case tooLong
    case io(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedCodec(let name):
            return "Can't decode \(name). Use WAV, AIFF, MP3, AAC, M4A, or ALAC."
        case .empty:
            return "That file has no audio."
        case .tooLong:
            return "Tracks longer than 12 minutes aren't supported yet."
        case .io(let message):
            return message
        }
    }
}

enum FileDecoder {
    static let allowedExtensions: Set<String> = [
        "wav", "wave", "aif", "aiff", "aifc", "mp3", "m4a", "aac", "caf", "alac"
    ]

    static var importTypes: [UTType] {
        var types: [UTType] = [.wav, .aiff, .mp3, .mpeg4Audio, .audio]
        if let aac = UTType("public.aac-audio") {
            types.insert(aac, at: 0)
        }
        return types
    }

    static func isSupported(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty || allowedExtensions.contains(ext)
    }

    /// ExtAudioFile decode + offline resample to 48 kHz stereo float32.
    static func decode(url: URL) throws -> DecodedClip {
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty && !allowedExtensions.contains(ext) {
            throw FileDecodeError.unsupportedCodec(".\(ext)")
        }

        var fileRef: ExtAudioFileRef?
        var err = ExtAudioFileOpenURL(url as CFURL, &fileRef)
        guard err == noErr, let file = fileRef else {
            throw FileDecodeError.unsupportedCodec(ext.isEmpty ? "this file" : ".\(ext)")
        }
        defer { ExtAudioFileDispose(file) }

        var asbd = AudioStreamBasicDescription()
        var propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        err = ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &propSize, &asbd)
        guard err == noErr else {
            throw FileDecodeError.io("Couldn't read the file format.")
        }

        var client = AudioStreamBasicDescription(
            mSampleRate: 48_000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 8,
            mFramesPerPacket: 1,
            mBytesPerFrame: 8,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        err = ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, propSize, &client)
        guard err == noErr else {
            throw FileDecodeError.unsupportedCodec(fourCC(asbd.mFormatID))
        }

        var fileFrames: Int64 = 0
        propSize = UInt32(MemoryLayout<Int64>.size)
        err = ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileLengthFrames, &propSize, &fileFrames)
        guard err == noErr else {
            throw FileDecodeError.io("Couldn't read file length.")
        }

        let srcRate = asbd.mSampleRate > 0 ? asbd.mSampleRate : 48_000
        let estimated = UInt32(Double(max(fileFrames, 0)) * (48_000 / srcRate)) + 64
        if estimated > 48_000 * 60 * 12 {
            throw FileDecodeError.tooLong
        }

        var pcm = [Float](repeating: 0, count: Int(estimated) * 2)
        var totalRead: UInt32 = 0
        try pcm.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else {
                throw FileDecodeError.io("Decode buffer missing.")
            }
            var remaining = estimated
            var offset = 0
            while remaining > 0 {
                let chunk = min(remaining, 4096)
                var framesToRead = chunk
                var abl = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(
                        mNumberChannels: 2,
                        mDataByteSize: chunk * 8,
                        mData: base.advanced(by: offset * 2)
                    )
                )
                err = ExtAudioFileRead(file, &framesToRead, &abl)
                if err != noErr {
                    throw FileDecodeError.io("Decode failed (\(err)).")
                }
                if framesToRead == 0 {
                    break
                }
                totalRead += framesToRead
                remaining -= framesToRead
                offset += Int(framesToRead)
            }
        }

        if totalRead == 0 {
            throw FileDecodeError.empty
        }
        let extra = (Int(estimated) - Int(totalRead)) * 2
        if extra > 0 && extra <= pcm.count {
            pcm.removeLast(extra)
        }

        return DecodedClip(
            pcm: pcm,
            frames: totalRead,
            sourceSampleRate: srcRate,
            sourceChannels: asbd.mChannelsPerFrame,
            resampled: abs(srcRate - 48_000) > 0.5
        )
    }

    private static func fourCC(_ id: AudioFormatID) -> String {
        let bytes: [UInt8] = [
            UInt8((id >> 24) & 0xFF),
            UInt8((id >> 16) & 0xFF),
            UInt8((id >> 8) & 0xFF),
            UInt8(id & 0xFF)
        ]
        let raw = String(bytes: bytes, encoding: .ascii)?.trimmingCharacters(in: .controlCharacters)
        if let raw, !raw.isEmpty {
            return raw
        }
        return "this codec"
    }
}

enum BundledAudio {
    static func url(for trackId: String) -> URL? {
        switch trackId {
        case "t1", "t6":
            return Bundle.main.url(forResource: "side_street_48k", withExtension: "wav")
        case "t2":
            return Bundle.main.url(forResource: "plastic_peg_441", withExtension: "wav")
        default:
            return nil
        }
    }
}
