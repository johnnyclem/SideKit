import SwiftUI

struct KnobView: View {
    let label: String
    @Binding var value: Double
    var rangeMin: Double = -1
    var rangeMax: Double = 1
    var size: CGFloat = 40
    var bipolar: Bool = false

    @State private var dragStart: Double?

    private var normalized: Double {
        (value - rangeMin) / (rangeMax - rangeMin)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(SKTheme.inset)
                    .overlay(Circle().stroke(SKTheme.borderStrong, lineWidth: 1))
                Circle()
                    .trim(from: 0.12, to: 0.12 + 0.76 * normalized)
                    .stroke(SKTheme.accent.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(90))
                Capsule()
                    .fill(SKTheme.fg)
                    .frame(width: 2, height: size * 0.28)
                    .offset(y: -size * 0.18)
                    .rotationEffect(.degrees(-135 + 270 * normalized))
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if dragStart == nil { dragStart = value }
                        let delta = -Double(g.translation.height) / 140
                        let span = rangeMax - rangeMin
                        value = Swift.min(rangeMax, Swift.max(rangeMin, (dragStart ?? value) + delta * span))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(SKTheme.subtle)
        }
        .accessibilityLabel(label)
        .accessibilityValue(String(format: "%.1f", value))
    }
}

struct VerticalFader: View {
    @Binding var value: Double
    var height: CGFloat = 148

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(SKTheme.border)
                    .frame(width: 3)
                RoundedRectangle(cornerRadius: 3)
                    .fill(SKTheme.accent)
                    .frame(width: 22, height: 10)
                    .offset(y: -(value * (h - 10)))
            }
            .frame(width: w, height: h)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let y = 1 - (g.location.y / h)
                        value = min(1, max(0, y))
                    }
            )
        }
        .frame(width: 28, height: height)
        .accessibilityElement()
        .accessibilityLabel("Fader")
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            let step = 0.05
            switch direction {
            case .increment: value = min(1, value + step)
            case .decrement: value = max(0, value - step)
            @unknown default: break
            }
        }
    }
}

struct LevelMeter: View {
    var level: Double
    var width: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2).fill(SKTheme.inset)
                RoundedRectangle(cornerRadius: 2)
                    .fill(level > 0.9 ? SKTheme.warn : SKTheme.meter)
                    .frame(height: max(2, h * level))
            }
        }
        .frame(width: width)
    }
}

struct HorizontalMeter: View {
    var level: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(SKTheme.border)
                Capsule()
                    .fill(SKTheme.meter)
                    .frame(width: max(2, geo.size.width * level))
            }
        }
        .frame(height: 4)
    }
}

struct SegmentedPills<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let title: KeyPath<T, String>

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { opt in
                Button {
                    selection = opt
                } label: {
                    Text(opt[keyPath: title])
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(selection == opt ? SKTheme.accentFg : SKTheme.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(selection == opt ? SKTheme.accent : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(SKTheme.inset)
        .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous)
                .stroke(SKTheme.border, lineWidth: 1)
        )
    }
}

struct ToggleChip: View {
    let label: String
    let systemImage: String
    var danger: Bool = false
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
            }
            .foregroundStyle(isOn ? (danger ? SKTheme.fg : SKTheme.accentFg) : SKTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                isOn
                    ? (danger ? SKTheme.danger.opacity(0.28) : SKTheme.accent)
                    : SKTheme.inset
            )
            .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous)
                    .stroke(isOn ? (danger ? SKTheme.danger.opacity(0.5) : SKTheme.accent.opacity(0.4)) : SKTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct CompactMenu<T: Hashable>: View {
    let title: String
    let options: [T]
    @Binding var selection: T
    let label: KeyPath<T, String>

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { opt in
                Button(opt[keyPath: label]) { selection = opt }
            }
        } label: {
            HStack {
                Text(selection[keyPath: label])
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SKTheme.fg)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(SKTheme.subtle)
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(SKTheme.inset)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(SKTheme.border, lineWidth: 1)
            )
        }
        .accessibilityLabel(title)
    }
}
