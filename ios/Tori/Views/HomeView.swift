import SwiftUI

struct HomeView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DataStore.self) private var data
    @Environment(ProgressStore.self) private var progress
    @Environment(\.palette) private var p
    @Environment(\.navigate) private var navigate

    private struct Feature: Identifiable {
        let glyph: String, ja: String, destination: Destination
        var id: Destination { destination }
    }

    private let features: [Feature] = [
        .init(glyph: "語", ja: "たんご", destination: .vocab),
        .init(glyph: "文", ja: "ぶんぽう", destination: .grammar),
        .init(glyph: "字", ja: "かんじ", destination: .kanji),
        .init(glyph: "動", ja: "どうし", destination: .verbForms),
        .init(glyph: "数", ja: "かぞえかた", destination: .counters),
        .init(glyph: "音", ja: "どうおん", destination: .homophones),
    ]

    private static let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        let ids = data.vocab(settings.level).map(\.id)
        let due = progress.dueCards(in: ids).count
        let learnedCount = ids.filter { progress.cards[$0] != nil && progress.cards[$0]?.state != .new }.count
        let grammar = data.grammar(settings.level)
        let grammarLearned = grammar.filter { progress.isLearned($0.id) }.count

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    LevelPicker()

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(due)")
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                                .accessibilityIdentifier("home.dueCount")
                            Text(settings.t("dashboard.cardsDue")).font(.subheadline).foregroundStyle(p.muted)
                        }
                        if due == 0 {
                            Text(settings.t("dashboard.allDone")).font(.footnote).foregroundStyle(p.muted)
                        }
                        Button { navigate(.review) } label: {
                            Text(settings.t(due > 0 ? "dashboard.reviewNow" : "dashboard.learnNew"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.toriPrimary)
                        .accessibilityIdentifier("home.reviewNow")
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glass(strong: true, radius: Radius.sheet)

                    HStack(spacing: 12) {
                        stat(title: settings.t("dashboard.newWords"), value: "\(max(ids.count - learnedCount, 0))",
                             progress: ids.isEmpty ? 0 : Double(learnedCount) / Double(ids.count))
                        stat(title: settings.t("dashboard.grammarPoints"), value: "\(grammarLearned)/\(grammar.count)",
                             progress: grammar.isEmpty ? 0 : Double(grammarLearned) / Double(grammar.count))
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(features) { f in
                            Button { navigate(f.destination) } label: {
                                HStack(spacing: 12) {
                                    Text(f.glyph).jp(30).foregroundStyle(p.accent).frame(width: 38)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(settings.t(f.destination.titleKey)).font(.subheadline.weight(.semibold)).lineLimit(2)
                                        Text(f.ja).jp(11, weight: .regular).foregroundStyle(p.muted)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                                .glass(radius: Radius.card, shadowed: false)
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityIdentifier("home.feature.\(f.destination.rawValue)")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .toriScreen(title: "")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let greeting = settings.t(hour < 11 ? "ios.greeting.morning" : hour < 18 ? "ios.greeting.day" : "ios.greeting.evening")
        let dateLabel = "\(cal.component(.month, from: now))月\(cal.component(.day, from: now))日（\(Self.weekdays[cal.component(.weekday, from: now) - 1])）"
        return HStack(spacing: 16) {
            Text("鳥").jp(38, weight: .bold)
                .frame(width: 68, height: 68)
                .glass(strong: true, radius: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting).jp(32, weight: .bold)
                Text("\(dateLabel) · \(settings.t("dashboard.subtitle", ["level": settings.level.label]))")
                    .font(.footnote).foregroundStyle(p.muted)
            }
        }
    }

    private func stat(title: String, value: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(p.muted)
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded))
            CapsuleProgress(value: progress)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard()
    }
}
