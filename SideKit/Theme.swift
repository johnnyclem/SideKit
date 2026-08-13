import SwiftUI

enum SKTheme {
    static let bg = Color(red: 0.039, green: 0.039, blue: 0.043)
    static let elevated = Color(red: 0.071, green: 0.071, blue: 0.078)
    static let panel = Color(red: 0.086, green: 0.086, blue: 0.102)
    static let inset = Color(red: 0.055, green: 0.055, blue: 0.063)
    static let chrome = Color(red: 0.110, green: 0.110, blue: 0.125)
    static let fg = Color(red: 0.949, green: 0.949, blue: 0.957)
    static let muted = Color(red: 0.604, green: 0.604, blue: 0.639)
    static let subtle = Color(red: 0.420, green: 0.420, blue: 0.455)
    static let border = Color(red: 0.165, green: 0.165, blue: 0.188)
    static let borderStrong = Color(red: 0.227, green: 0.227, blue: 0.259)
    static let accent = Color(red: 0.847, green: 0.863, blue: 0.894)
    static let accentFg = Color(red: 0.039, green: 0.039, blue: 0.043)
    static let chA = Color(red: 0.910, green: 0.910, blue: 0.925)
    static let chB = Color(red: 0.545, green: 0.576, blue: 0.639)
    static let warn = Color(red: 0.769, green: 0.647, blue: 0.455)
    static let ok = Color(red: 0.490, green: 0.604, blue: 0.518)
    static let danger = Color(red: 0.690, green: 0.439, blue: 0.439)
    static let meter = Color(red: 0.816, green: 0.831, blue: 0.863)

    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
}

extension View {
    func skPanel() -> some View {
        self
            .background(SKTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous)
                    .stroke(SKTheme.border, lineWidth: 1)
            )
    }

    func skLabel() -> some View {
        self
            .font(.system(size: 10, weight: .semibold, design: .default))
            .tracking(1.2)
            .foregroundStyle(SKTheme.subtle)
            .textCase(.uppercase)
    }
}
