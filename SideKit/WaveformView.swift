import SwiftUI

struct WaveformOverview: View {
    let peaks: PeakOverview?
    let playhead: Double
    let accent: Color
    /// Normalized 0...1 loop region (SK-034), drawn as a tinted band.
    var loop: ClosedRange<Double>?
    /// Normalized 0...1 hot cue positions (nil = slot unset), drawn as numbered ticks.
    var cues: [Double?] = []
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
        .accessibilityAdjustableAction { direction in
            let step = 0.02
            switch direction {
            case .increment: onSeek(min(1, playhead + step))
            case .decrement: onSeek(max(0, playhead - step))
            @unknown default: break
            }
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let mid = size.height * 0.5
        let pos = min(1, max(0, playhead))

        if let loop {
            let x0 = size.width * CGFloat(loop.lowerBound)
            let x1 = size.width * CGFloat(loop.upperBound)
            let band = Path(CGRect(x: x0, y: 0, width: max(2, x1 - x0), height: size.height))
            ctx.fill(band, with: .color(SKTheme.warn.opacity(0.22)))
        }

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
                let path = Path(CGRect(x: x, y: top, width: bar, height: h))
                ctx.fill(path, with: .color(played ? accent.opacity(0.92) : SKTheme.borderStrong.opacity(0.85)))
            }
        } else {
            var midline = Path()
            midline.move(to: CGPoint(x: 8, y: mid))
            midline.addLine(to: CGPoint(x: size.width - 8, y: mid))
            ctx.stroke(midline, with: .color(SKTheme.borderStrong), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }

        for (idx, cue) in cues.enumerated() {
            guard let cue else { continue }
            let cx = size.width * CGFloat(min(1, max(0, cue)))
            let tick = Path(CGRect(x: cx - 0.75, y: 0, width: 1.5, height: size.height))
            ctx.fill(tick, with: .color(SKTheme.chB))
            let badge = Path(roundedRect: CGRect(x: cx - 6, y: size.height - 13, width: 12, height: 12), cornerRadius: 3)
            ctx.fill(badge, with: .color(SKTheme.chB))
            ctx.draw(
                Text("\(idx + 1)").font(.system(size: 8, weight: .bold)).foregroundStyle(SKTheme.bg),
                at: CGPoint(x: cx, y: size.height - 7)
            )
        }

        let nx = size.width * CGFloat(pos)
        let needle = Path(CGRect(x: nx - 0.75, y: 2, width: 1.5, height: size.height - 4))
        ctx.fill(needle, with: .color(SKTheme.accent))
        let cap = Path(ellipseIn: CGRect(x: nx - 3, y: 1, width: 6, height: 6))
        ctx.fill(cap, with: .color(SKTheme.accent))
    }
}
