import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var store: MixerStore
    @State private var importing = false

    private var filtered: [Track] {
        let q = store.libraryFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = store.libraryTracks
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.title.lowercased().contains(q)
                || $0.artist.lowercased().contains(q)
                || $0.key.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Library")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SKTheme.fg)
                Spacer()
                Button {
                    importing = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                        Text(store.isDecoding ? "DECODING…" : "IMPORT")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(SKTheme.accentFg)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(SKTheme.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(store.isDecoding)
            }

            if let banner = store.decodeBanner {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(SKTheme.warn)
                    Text(banner)
                        .font(.system(size: 12))
                        .foregroundStyle(SKTheme.fg)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button("Dismiss") { store.dismissDecodeBanner() }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SKTheme.muted)
                }
                .padding(10)
                .background(SKTheme.warn.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous)
                        .stroke(SKTheme.warn.opacity(0.35), lineWidth: 1)
                )
            }

            Text("WAV, AIFF, MP3, AAC, M4A, ALAC. Non-48 kHz files resample on load.")
                .font(.system(size: 11))
                .foregroundStyle(SKTheme.subtle)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(SKTheme.subtle)
                TextField("Search tracks, key, artist", text: $store.libraryFilter)
                    .font(.system(size: 14))
                    .foregroundStyle(SKTheme.fg)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(SKTheme.inset)
            .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous)
                    .stroke(SKTheme.border, lineWidth: 1)
            )

            HStack(spacing: 6) {
                loadBtn(1, "Load → Deck A")
                loadBtn(2, "Load → Deck B")
            }

            VStack(spacing: 6) {
                ForEach(filtered) { track in
                    Button {
                        store.selectedTrackId = track.id
                        store.loadTrack(ch: store.loadTarget, id: track.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: track.isImported ? "waveform" : "opticaldisc")
                                .font(.system(size: 18))
                                .foregroundStyle(SKTheme.meter)
                                .frame(width: 40, height: 40)
                                .background(SKTheme.inset)
                                .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(SKTheme.fg)
                                    .lineLimit(1)
                                Text("\(track.artist) · \(track.key)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(SKTheme.muted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Formatters.bpm(track.bpm))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(SKTheme.muted)
                                Text(Formatters.time(track.duration))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(SKTheme.subtle)
                                badge(track)
                            }
                        }
                        .padding(10)
                        .background(store.selectedTrackId == track.id ? SKTheme.chrome : SKTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous)
                                .stroke(store.selectedTrackId == track.id ? SKTheme.borderStrong : SKTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: FileDecoder.importTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                store.importURLs(urls)
            case .failure(let error):
                store.decodeBanner = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func badge(_ track: Track) -> some View {
        let a = store.ch1.trackId == track.id
        let b = store.ch2.trackId == track.id
        if track.resampled {
            Text("48K")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(SKTheme.warn)
        } else if track.isImported {
            Text("FILE")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(SKTheme.ok)
        } else if a || b {
            Text(a && b ? "A+B" : a ? "A" : "B")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(SKTheme.ok)
        }
    }

    private func loadBtn(_ ch: Int, _ title: String) -> some View {
        Button {
            store.loadTarget = ch
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(store.loadTarget == ch ? SKTheme.accentFg : SKTheme.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(store.loadTarget == ch ? SKTheme.accent : SKTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous)
                        .stroke(store.loadTarget == ch ? SKTheme.accent.opacity(0.4) : SKTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
