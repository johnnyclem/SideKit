import Foundation

/// USB 8x4 channel matrix persistence (SK-027): "Persist last matrix per mode."
final class USBMatrixStore: ObservableObject {
    static let shared = USBMatrixStore()

    static let usbSlots = ["usb-1", "usb-2", "usb-3", "usb-4", "usb-5", "usb-6", "usb-7", "usb-8"]

    static let roleOptions = [
        "Deck A L/R out", "Deck B L/R out", "Sidekick return", "Cue / preview",
        "FX send", "FX return", "Aux record", "Master record", "Unused",
    ]

    private static let defaultsByMode: [String: [String]] = [
        "External": ["Deck A L/R out", "Deck B L/R out", "Sidekick return", "Cue / preview", "FX send", "FX return", "Aux record", "Master record"],
        "Internal": ["Master record", "Cue / preview", "Aux record", "Unused", "Unused", "Unused", "Unused", "Unused"],
        "MIDI": ["Unused", "Unused", "Unused", "Unused", "Unused", "Unused", "Unused", "Unused"],
    ]

    @Published private(set) var byMode: [String: [String]]

    private let key = "sk.usbmatrix.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            byMode = decoded
        } else {
            byMode = Self.defaultsByMode
        }
    }

    func roles(for mode: String) -> [String] {
        byMode[mode] ?? Self.defaultsByMode[mode] ?? Array(repeating: "Unused", count: 8)
    }

    func setRole(_ role: String, slotIndex: Int, mode: String) {
        var roles = roles(for: mode)
        guard roles.indices.contains(slotIndex) else { return }
        roles[slotIndex] = role
        byMode[mode] = roles
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(byMode) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
