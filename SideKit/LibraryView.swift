import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var store: MixerStore
    @State private var importing = false

    private func filter(_ tracks: [Track]) -> [Track] {
        let q = store.libraryFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.lowercased().contains(q)
                || $0.artist.lowercased().contains(q)
                || $0.key.lowercased().contains(q)
        }
    }

    private var filteredUser: [Track] { filter(store.library.userTracks) }
    private var filteredDemo: [Track] { filter(DemoLibrary.tracks) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(SKTheme.subtle)
                    TextField("Search", text: $store.libraryFilter)
                        .font(.system(size: 14))
                        .foregroundStyle(SKTheme.fg)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(SKTheme.inset)
                .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: SKTheme.radiusMD, style: .continuous)
                        .stroke(SKTheme.border, lineWidth: 1)
                )

                Button {
                    importing = true
                } label: {
                    Image(systemName: store.isDecoding ? "hourglass" : "square.and.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SKTheme.accentFg)
                        .frame(width: 36, height: 36)
                        .background(SKTheme.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(store.isDecoding)
                .accessibilityLabel("Import audio files")
            }

            if let banner = store.decodeBanner {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(SKTheme.warn)
                    Text(banner)
                        .font(.system(size: 12))
                        .foregroundStyle(SKTheme.fg)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Button("OK") { store.dismissDecodeBanner() }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SKTheme.muted)
                }
                .padding(8)
                .background(SKTheme.warn.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
            }

            HStack(spacing: 6) {
                loadBtn(1, "→ A")
                loadBtn(2, "→ B", locked: !store.isPro)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    if store.library.userTracks.isEmpty {
                        emptyState
                    } else {
                        Text("YOUR LIBRARY").skLabel().padding(.top, 2)
                        ForEach(filteredUser) { track in
                            row(track, removable: true)
                        }
                    }
                    Text("DEMO TRACKS").skLabel().padding(.top, 6)
                    ForEach(filteredDemo) { track in
                        row(track, removable: false)
                    }
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

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 20))
                .foregroundStyle(SKTheme.subtle)
            Text("No imported tracks yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SKTheme.muted)
            Text("Tap import to add WAV, AIFF, MP3, AAC, M4A or ALAC files from Files.")
                .font(.system(size: 11))
                .foregroundStyle(SKTheme.subtle)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .skPanel()
    }

    private func row(_ track: Track, removable: Bool) -> some View {
        HStack(spacing: 6) {
            Button {
                store.selectedTrackId = track.id
                store.loadTrack(ch: store.loadTarget, id: track.id)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: track.isImported ? "waveform" : "opticaldisc")
                        .font(.system(size: 18))
                        .foregroundStyle(SKTheme.meter)
                        .frame(width: 36, height: 36)
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
                        Text(Formatters.bpm(track.bpm) + (track.bpmIsEstimated ? "*" : ""))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(SKTheme.muted)
                        Text(Formatters.time(store.duration(for: track)))
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
            .accessibilityLabel("\(track.title) by \(track.artist), \(Formatters.bpm(track.bpm)) BPM")
            .accessibilityHint("Loads into deck \(store.loadTarget == 1 ? "A" : "B")")

            if removable {
                Button(role: .destructive) {
                    store.removeTrack(id: track.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(SKTheme.danger)
                        .frame(width: 32, height: 56)
                        .background(SKTheme.inset)
                        .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(track.title) from library")
            }
        }
    }

    @ViewBuilder
    private func badge(_ track: Track) -> some View {
        let a = store.ch1.trackId == track.id
        let b = store.ch2.trackId == track.id
        if a || b {
            Text(a && b ? "A+B" : a ? "A" : "B")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(SKTheme.ok)
        } else if track.resampled {
            Text("48K")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(SKTheme.warn)
        } else if track.isImported {
            Text("FILE")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(SKTheme.ok)
        }
    }

    private func loadBtn(_ ch: Int, _ title: String, locked: Bool = false) -> some View {
        Button {
            store.loadTarget = ch
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 8))
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(store.loadTarget == ch ? SKTheme.accentFg : SKTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(store.loadTarget == ch ? SKTheme.accent : SKTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SKTheme.radiusSM, style: .continuous)
                    .stroke(store.loadTarget == ch ? SKTheme.accent.opacity(0.4) : SKTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Load target deck \(ch == 1 ? "A" : "B")")
        .accessibilityAddTraits(store.loadTarget == ch ? .isSelected : [])
    }
}
