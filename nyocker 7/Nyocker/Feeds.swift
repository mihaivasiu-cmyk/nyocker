import SwiftUI

struct LiveEvent: Codable, Identifiable {
    let id: String
    let title: String
    let venue: String
    let start: String
    let spot: String?
    let link: String?
    let note: String?

    private static let parser: DateFormatter = {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "yyyy-MM-dd'T'HH:mmxxx"
        return format
    }()

    private static let label: DateFormatter = {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_GB")
        format.timeZone = TimeZone(identifier: "Europe/Budapest")
        format.dateFormat = "EEE d MMM, HH:mm"
        return format
    }()

    var date: Date? { Self.parser.date(from: start) }
    var when: String { date.map(Self.label.string(from:)) ?? String(start.prefix(10)) }
    var url: URL? {
        guard let link, let url = URL(string: link), url.scheme == "https" else { return nil }
        return url
    }
}

struct EventsScreen: View {
    @EnvironmentObject private var progress: Progress
    @EnvironmentObject private var events: EventStore
    @Environment(\.theme) private var theme
    @State private var reading: URL?
    let showOnMap: (Spot) -> Void

    /// The feed drops past events too, but a phone may be holding an old copy.
    private var upcoming: [LiveEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        return events.feed.items.filter { $0.date.map { $0 >= today } ?? false }
    }

    private var status: String {
        events.offline ? "Offline. Showing saved events." : "Real dates from around the district."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(alignment: .top) {
                    ScreenTitle(title: "Quest board", subtitle: status)
                    Button { Task { await events.refresh(force: true) } } label: {
                        Group {
                            if events.loading {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise").font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundStyle(theme.accent)
                        .frame(width: 44, height: 44)
                    }
                    .disabled(events.loading)
                    .accessibilityLabel("Refresh events")
                }

                if upcoming.isEmpty {
                    Text("No dated events right now. New ones land here as soon as they're posted.")
                        .font(.subheadline).foregroundStyle(theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
                }
                ForEach(upcoming) { event in
                    card(pill: event.when, pillColor: theme.fill, title: event.title, place: event.venue,
                         detail: event.note, id: event.id, spot: event.spot, link: event.url)
                }

                Text("Regulars").font(.title3.weight(.bold)).foregroundStyle(theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                ForEach(Content.shared.events) { event in
                    card(pill: event.when, pillColor: Color(css: event.color), title: event.title, place: event.place,
                         detail: event.d, id: event.id, spot: event.spot, link: nil)
                }
            }
            .padding(16)
        }
        .background(theme.bg.ignoresSafeArea())
        .sheet(item: $reading) { WebPage(url: $0).ignoresSafeArea() }
    }

    private func card(pill: String, pillColor: Color, title: String, place: String, detail: String?,
                      id: String, spot: String?, link: URL?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pill)
                .font(.caption.weight(.bold)).foregroundStyle(Color.ink)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(pillColor, in: Capsule())
            Text(title).font(.title3.weight(.bold)).foregroundStyle(theme.text).padding(.top, 4)
            Text(place).font(.subheadline).foregroundStyle(theme.link)
            if let detail {
                Text(detail).font(.subheadline).foregroundStyle(theme.text)
            }
            HStack(spacing: 10) {
                Button(progress.going.contains(id) ? "You're in" : "I'm in") {
                    progress.toggle(id, in: \.going)
                }
                .buttonStyle(PrimaryButton(fill: progress.going.contains(id) ? .mint : nil))
                if let link {
                    Button("Details") { reading = link }.buttonStyle(OutlineButton())
                }
                if let spot = Content.shared.spots.first(where: { $0.id == spot }) {
                    Button("On map") { showOnMap(spot) }.buttonStyle(OutlineButton())
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
