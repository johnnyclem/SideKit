import SwiftUI

struct FXView: View {
    @EnvironmentObject private var store: MixerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Performance FX")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SKTheme.fg)
                Spacer()
                Text(store.fxActive ? "ENGAGED" : "STANDBY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(store.fxActive ? SKTheme.ok : SKTheme.subtle)
            }

            Text("Six Sidekick-style punch-in effects. Hold the pad to engage — X/Y map to the selected effect.")
                .font(.system(size: 11))
                .foregroundStyle(SKTheme.subtle)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(FxId.allCases) { item in
                    Button {
                        store.fx = item
                        store.pushFx()
                    } label: {
                        Text(item.short)
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(store.fx == item ? SKTheme.accentFg : SKTheme.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(store.fx == item ? SKTheme.accent : SKTheme.panel)
                            .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous)
                                    .stroke(store.fx == item ? SKTheme.accent.opacity(0.5) : SKTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            ForcePad(
                x: store.fxX,
                y: store.fxY,
                active: store.fxActive,
                caption: store.fx.label
            ) { x, y, down in
                store.fxActive = down
                store.setFxPad(x: x, y: y)
            }

            HStack(spacing: 10) {
                Text("DEPTH")
                    .font(.system(size: 10))
                    .foregroundStyle(SKTheme.subtle)
                    .frame(width: 48, alignment: .leading)
                Slider(value: $store.fxDepth, in: 0...1)
                    .tint(SKTheme.accent)
                    .onChange(of: store.fxDepth) { _, _ in store.pushFx() }
                Button {
                    store.fxSeries.toggle()
                } label: {
                    Text(store.fxSeries ? "SERIES" : "PARALLEL")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(store.fxSeries ? SKTheme.fg : SKTheme.muted)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(store.fxSeries ? SKTheme.chrome : SKTheme.inset)
                        .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous)
                                .stroke(SKTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            Text("Hold the pad to engage. Matches Sidekick force pad + mod stick workflow.")
                .font(.system(size: 11))
                .foregroundStyle(SKTheme.subtle)
        }
    }
}

struct ForcePad: View {
    var x: Double
    var y: Double
    var active: Bool
    var caption: String
    var onChange: (_ x: Double, _ y: Double, _ down: Bool) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SKTheme.inset
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                    p.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
                }
                .stroke(SKTheme.borderStrong.opacity(0.5), lineWidth: 1)

                Text("MOD STICK / FORCE PAD")
                    .font(.system(size: 10))
                    .tracking(1)
                    .foregroundStyle(SKTheme.subtle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)

                Text(caption)
                    .font(.system(size: 10))
                    .foregroundStyle(SKTheme.subtle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(10)

                Circle()
                    .stroke(active ? SKTheme.accent : SKTheme.muted, lineWidth: 2)
                    .background(Circle().fill(active ? SKTheme.accent.opacity(0.3) : SKTheme.fg.opacity(0.08)))
                    .frame(width: 20, height: 20)
                    .scaleEffect(active ? 1.1 : 1)
                    .position(x: geo.size.width * x, y: geo.size.height * (1 - y))
            }
            .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous)
                    .stroke(SKTheme.borderStrong, lineWidth: 1)
            )
            .overlay {
                if active {
                    RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous)
                        .fill(SKTheme.accent.opacity(0.05))
                        .allowsHitTesting(false)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let nx = min(1, max(0, g.location.x / geo.size.width))
                        let ny = min(1, max(0, 1 - g.location.y / geo.size.height))
                        onChange(nx, ny, true)
                    }
                    .onEnded { _ in
                        onChange(x, y, false)
                    }
            )
        }
        .aspectRatio(4 / 3, contentMode: .fit)
    }
}
