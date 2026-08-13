import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: MixerStore
    @ObservedObject private var library = LibraryStore.shared
    @State private var showImporter = false
    @State private var showImportError = false

    private var filteredDemo: [Track] {
        filter(DemoLibrary.tracks)
    }

    private var filteredUser: [Track] {
        filter(library.userTracks)
    }

    private func filter(_ tracks: [Track]) -> [Track] {
        let q = store.libraryFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return tracks }
        return tracks.filter {
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
                    showImporter = true
                } label: {
                    Label("Import", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SKTheme.accentFg)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(SKTheme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Import audio files")
            }

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

            if library.userTracks.isEmpty {
                emptyState
            } else {
                sectionHeader("YOUR LIBRARY")
                VStack(spacing: 6) {
                    ForEach(filteredUser) { track in
                        row(track, removable: true)
                    }
                }
            }

            sectionHeader("DEMO TRACKS")
            VStack(spacing: 6) {
                ForEach(filteredDemo) { track in
                    row(track, removable: false)
                }
            }
        }
        .sheet(isPresented: $showImporter) {
            AudioFilePicker { urls in
                Task {
                    await library.importFiles(urls)
                    if library.importError != nil { showImportError = true }
                }
            }
            .ignoresSafeArea()
        }
        .alert("Import problem", isPresented: $showImportError, presenting: library.importError) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 22))
                .foregroundStyle(SKTheme.subtle)
            Text("No imported tracks yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SKTheme.muted)
            Text("Tap Import to add AAC, MP3, ALAC, WAV, or AIFF files from Files or a share sheet.")
                .font(.system(size: 11))
                .foregroundStyle(SKTheme.subtle)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .skPanel()
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).skLabel().padding(.top, 4)
    }

    @ViewBuilder
    private func row(_ track: Track, removable: Bool) -> some View {
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
                    Text(Formatters.bpm(track.bpm) + (track.bpmIsEstimated ? "*" : ""))
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
        .accessibilityLabel("\(track.title) by \(track.artist), \(Formatters.bpm(track.bpm)) BPM")
        .swipeActions(edge: .trailing) {
            if removable {
                Button(role: .destructive) {
                    library.remove(id: track.id)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
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
        .accessibilityLabel(title)
    }
}
