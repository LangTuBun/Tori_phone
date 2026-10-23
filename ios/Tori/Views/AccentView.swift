import SwiftUI

/// アクセント辞典: look a word up (kanji or kana) and see its pitch pattern.
struct AccentView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var p

    @State private var dictionary: AccentDictionary?
    @State private var failed = false
    @State private var query = ""
    @State private var results: [AccentRow] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Text(settings.t("accent.intro")).font(.footnote).foregroundStyle(p.muted)
                    Text(status).font(.caption.weight(.semibold)).foregroundStyle(p.muted)
                        .accessibilityIdentifier("accent.status")
                    ForEach(results) { r in row(r) }
                    Text(settings.t("accent.credit")).font(.caption2).foregroundStyle(p.muted).padding(.top, 16)
                }
                .padding(.horizontal, 16)
            }
            .toriScreen(title: settings.t("nav.accent"))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: settings.t("accent.placeholder"))
            .task {
                let loaded = await Task.detached(priority: .userInitiated) { AccentDictionary.load() }.value
                dictionary = loaded
                failed = loaded == nil
            }
            .task(id: "\(query)|\(dictionary != nil)") {   // re-run once the dictionary arrives
                guard let dictionary else { results = []; return }
                // Debounce typing, then scan the 124k rows off the main thread.
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                let q = query
                let found = await Task.detached(priority: .userInitiated) { dictionary.search(q) }.value
                if !Task.isCancelled { results = found }
            }
        }
    }

    private var status: String {
        if failed { return settings.t("accent.loadFailed") }
        guard let dictionary else { return settings.t("accent.loading") }
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            return settings.t("accent.resultCount", ["n": results.count, "max": AccentDictionary.maxResults])
        }
        return settings.t("accent.entries", ["n": dictionary.rows.count.formatted()])
    }

    private func row(_ r: AccentRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.surface).jp(21, weight: .black)
                if r.surface != r.reading { Text(r.reading).jp(12, weight: .semibold).foregroundStyle(p.muted) }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                ForEach(r.pitches, id: \.self) { pitch in PitchAccentView(kana: r.reading, pitch: pitch, size: 15) }
            }
            SpeakButton(text: r.reading)
        }
        .padding(14)
        .solidCard(radius: Radius.small)
    }
}
