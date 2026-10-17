import Foundation
import MetricKit
#if canImport(UIKit)
import UIKit
#endif

/// SK-051: opt-in crash/analytics with no third-party SDKs. Uses Apple's on-device
/// MetricKit — no data leaves the device unless the user later opts into diagnostics
/// export (SK-050), which is an explicit share-sheet action.
final class CrashReporting: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashReporting()

    private let optInKey = "sk.analytics.optIn"
    private let crashCountKey = "sk.analytics.crashCount"
    private let launchCountKey = "sk.analytics.launchCount"

    var isOptedIn: Bool {
        get { UserDefaults.standard.bool(forKey: optInKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: optInKey)
            if newValue { start() } else { stop() }
        }
    }

    /// Crash-free rate this run, computed locally from on-device counters only.
    var crashFreePercentString: String {
        let launches = max(1, UserDefaults.standard.integer(forKey: launchCountKey))
        let crashes = UserDefaults.standard.integer(forKey: crashCountKey)
        let rate = max(0, Double(launches - crashes) / Double(launches)) * 100
        return String(format: "%.1f%%", rate)
    }

    func recordLaunch() {
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: launchCountKey) + 1, forKey: launchCountKey)
        if isOptedIn { start() }
    }

    private func start() {
        MXMetricManager.shared.add(self)
    }

    private func stop() {
        MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        // On-device aggregate metrics only; SideKit does not transmit these anywhere.
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard isOptedIn else { return }
        let crashCount = payloads.reduce(0) { $0 + ($1.crashDiagnostics?.count ?? 0) }
        guard crashCount > 0 else { return }
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: crashCountKey) + crashCount, forKey: crashCountKey)
    }
}
