import SwiftUI

struct WaveformOverview: View {
    let peaks: PeakOverview?
    let playhead: Double
    let accent: Color
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                draw(ctx: ctx, size: size)
            }
            .transaction { $0.animation = nil }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = value.location.x / max(geo.size.width, 1)
                        onSeek(min(1, max(0, x)))
                    }
            )
        }
        .frame(height: 56)
        .background(SKTheme.inset)
        .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous)
                .stroke(SKTheme.border, lineWidth: 1)
        )
        .accessibilityLabel("Waveform")
        .accessibilityValue("\(Int(playhead * 100)) percent")
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let mid = size.height * 0.5
        let pos = min(1, max(0, playhead))

        if let peaks, !peaks.isEmpty {
            let n = peaks.bins
            let w = size.width / CGFloat(n)
            let bar = max(w * 0.72, 0.55)
            for i in 0..<n {
                let lo = CGFloat(peaks.mins[i])
                let hi = CGFloat(peaks.maxs[i])
                let yHi = mid - hi * mid * 0.92
                let yLo = mid - lo * mid * 0.92
                let top = min(yHi, yLo)
                let h = max(abs(yLo - yHi), 1.2)
                let x = CGFloat(i) * w + (w - bar) * 0.5
                let played = Double(i) / Double(n) <= pos
                var path = Path(CGRect(x: x, y: top, width: bar, height: h))
                ctx.fill(path, with: .color(played ? accent.opacity(0.92) : SKTheme.borderStrong.opacity(0.85)))
            }
        } else {
            var midline = Path()
            midline.move(to: CGPoint(x: 8, y: mid))
            midline.addLine(to: CGPoint(x: size.width - 8, y: mid))
            ctx.stroke(midline, with: .color(SKTheme.borderStrong), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }

        let nx = size.width * CGFloat(pos)
        var needle = Path(CGRect(x: nx - 0.75, y: 2, width: 1.5, height: size.height - 4))
        ctx.fill(needle, with: .color(SKTheme.accent))
        var cap = Path(ellipseIn: CGRect(x: nx - 3, y: 1, width: 6, height: 6))
        ctx.fill(cap, with: .color(SKTheme.accent))
    }
}
