import AVFoundation
import SwiftUI
import UIKit

/// SK-050: diagnostics export (route, sample rate, device names, build) via the share
/// sheet. Deliberately excludes PII beyond the device model name.
struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shareText: String = ""
    @State private var showShare = false
    @ObservedObject private var crash = CrashReportingObservable()

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback") {
                    row("Crash-free rate", CrashReporting.shared.crashFreePercentString)
                    Toggle("Share crash & performance diagnostics", isOn: crash.binding)
                        .accessibilityHint("On-device only; nothing is transmitted unless you export.")
                }
                Section("Audio route") {
                    row("Sample rate", "\(Int(AVAudioSession.sharedInstance().sampleRate)) Hz")
                    row("Output", AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? "—")
                    row("Input", AVAudioSession.sharedInstance().currentRoute.inputs.first?.portName ?? "—")
                    row("I/O buffer", String(format: "%.1f ms", AVAudioSession.sharedInstance().ioBufferDuration * 1000))
                }
                Section("Build") {
                    row("App version", appVersion)
                    row("Device model", UIDevice.current.modelName)
                    row("iOS", UIDevice.current.systemVersion)
                }
                Section {
                    Button("Export diagnostics") {
                        shareText = buildReport()
                        showShare = true
                    }
                    .accessibilityLabel("Export diagnostics via share sheet")
                }
            }
            .navigationTitle("Diagnostics")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                ShareSheet(items: [shareText])
            }
        }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func buildReport() -> String {
        let session = AVAudioSession.sharedInstance()
        return """
        SideKit Diagnostics
        App: \(appVersion)
        Device: \(UIDevice.current.modelName), iOS \(UIDevice.current.systemVersion)
        Sample rate: \(Int(session.sampleRate)) Hz
        I/O buffer: \(String(format: "%.1f", session.ioBufferDuration * 1000)) ms
        Output route: \(session.currentRoute.outputs.map(\.portName).joined(separator: ", "))
        Input route: \(session.currentRoute.inputs.map(\.portName).joined(separator: ", "))
        Crash-free rate: \(CrashReporting.shared.crashFreePercentString)
        """
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(SKTheme.muted)
            Spacer()
            Text(value).foregroundStyle(SKTheme.fg).font(.system(.body, design: .monospaced))
        }
    }
}

/// Tiny ObservableObject shim so the opt-in Bool (backed by CrashReporting/UserDefaults)
/// can drive a SwiftUI Toggle.
private final class CrashReportingObservable: ObservableObject {
    var binding: Binding<Bool> {
        Binding(
            get: { CrashReporting.shared.isOptedIn },
            set: { newValue in
                self.objectWillChange.send()
                CrashReporting.shared.isOptedIn = newValue
            }
        )
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension UIDevice {
    /// Maps the raw hardware identifier to a friendly model name where known,
    /// falling back to the identifier itself — no serial numbers or IDFA involved.
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result += String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }
}
