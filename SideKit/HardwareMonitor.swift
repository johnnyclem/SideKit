import AVFoundation
import Foundation

/// Watches AVAudioSession routes for a class-compliant USB device (Sidekick).
final class HardwareMonitor {
    struct Info {
        var deviceName: String?
        var inputChannels: Int
        var outputChannels: Int
        var sidekickLikely: Bool
    }

    var onChange: ((Info) -> Void)?

    func start() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(routeChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        emit()
    }

    @objc private func routeChanged(_ note: Notification) {
        emit()
    }

    private func emit() {
        let session = AVAudioSession.sharedInstance()
        let outs = session.currentRoute.outputs
        let ins = session.currentRoute.inputs
        let ports: [AVAudioSessionPortDescription] = outs + ins
        let names: [String] = ports.map { $0.portName }

        var usb = false
        for port in ports where port.portType == .usbAudio || port.portType == .hdmi {
            usb = true
            break
        }

        var match = false
        for name in names {
            let n = name.lowercased()
            if n.contains("sidekick") || n.contains("ep-136") || n.contains("ep136") || n.contains("ko") {
                match = true
                break
            }
        }

        let info = Info(
            deviceName: names.first,
            inputChannels: session.inputNumberOfChannels,
            outputChannels: session.outputNumberOfChannels,
            sidekickLikely: usb || match
        )
        onChange?(info)
    }
}
