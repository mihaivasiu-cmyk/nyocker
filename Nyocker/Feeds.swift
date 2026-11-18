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

    /// Upcoming dates in three groups, in Budapest time: today, the next six days, later.
    private var agenda: [AgendaDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        let sorted = upcoming.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        let groups = [
            AgendaDay(title: "Today", events: sorted.filter { ($0.date ?? .distantFuture) < tomorrow }),
            AgendaDay(title: "This week", events: sorted.filter { ($0.date ?? .distantFuture) >= tomorrow && ($0.date ?? .distantFuture) < nextWeek }),
            AgendaDay(title: "Later", events: sorted.filter { ($0.date ?? .distantFuture) >= nextWeek }),
        ]
        return groups.filter { !$0.events.isEmpty }
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
                    Text("No dated events right now. New ones land here, by date, as soon as they're posted.")
                        .font(.subheadline).foregroundStyle(theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
                }
                ForEach(agenda) { day in
                    Text(day.title).font(.title3.weight(.bold)).foregroundStyle(theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                    ForEach(day.events) { event in
                        AgendaRow(event: event, today: day.title == "Today", showOnMap: showOnMap)
                    }
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

struct AgendaDay: Identifiable {
    let title: String
    let events: [LiveEvent]

    var id: String { title }
}

/// One dated event on the agenda: the venue's own art and colour, tapping through to its spot.
struct AgendaRow: View {
    @EnvironmentObject private var progress: Progress
    @Environment(\.theme) private var theme
    @State private var reading: URL?
    let event: LiveEvent
    let today: Bool
    let showOnMap: (Spot) -> Void

    private var spot: Spot? { event.spot.flatMap { id in Content.shared.spots.first { $0.id == id } } }
    private var colour: Color {
        spot?.discoverPage.map { Color(css: $0.colors.brick) } ?? spot?.category.color ?? theme.raised
    }

    private static let clock: DateFormatter = {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_GB")
        format.timeZone = TimeZone(identifier: "Europe/Budapest")
        format.dateFormat = "HH:mm"
        return format
    }()

    private var when: String { today ? event.date.map(Self.clock.string(from:)) ?? event.when : event.when }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                if let spot { showOnMap(spot) }
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Text(when.uppercased()).font(.caption.weight(.heavy)).tracking(1)
                            .foregroundStyle(theme.accent)
                        Text(event.title).font(.headline).foregroundStyle(theme.text)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 4) {
                            Text(event.venue).font(.subheadline).foregroundStyle(theme.muted)
                            if spot != nil {
                                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(theme.muted)
                            }
                        }
                        if let note = event.note {
                            Text(note).font(.footnote).foregroundStyle(theme.muted).padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(spot == nil)
            .accessibilityHint(spot == nil ? "" : "Shows \(event.venue) on the map")
            HStack(spacing: 10) {
                Button(progress.going.contains(event.id) ? "You're in" : "I'm in") {
                    progress.toggle(event.id, in: \.going)
                }
                .buttonStyle(PrimaryButton(fill: progress.going.contains(event.id) ? .mint : nil))
                if let link = event.url {
                    Button("Event page") { reading = link }.buttonStyle(OutlineButton())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .leading) {
            // The map pin's colour, so the agenda and the map read the same.
            RoundedRectangle(cornerRadius: 2).fill(spot?.category.color ?? theme.line).frame(width: 4).padding(.vertical, 14)
        }
        .sheet(item: $reading) { WebPage(url: $0).ignoresSafeArea() }
    }

    /// The spot's Discover hero, cropped square; a category sign if the event has no spot.
    @ViewBuilder private var thumbnail: some View {
        if let hero = spot?.discoverPage?.hero {
            Image(hero).resizable().scaledToFill()
                .frame(width: 60, height: 60).clipped()
                .background(colour)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
        } else {
            Image(systemName: spot?.category.symbol ?? "calendar").font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.ink)
                .frame(width: 60, height: 60)
                .background(spot?.category.color ?? theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}

/// One spot's dates: from the live feed and the regulars in content.json.
/// Shown by the Events button when a spot has no programme page of its own.
struct SpotEventsSheet: View {
    @EnvironmentObject private var feed: EventStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var reading: URL?
    let spot: Spot

    private var live: [LiveEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        return feed.feed.items.filter { $0.spot == spot.id && ($0.date.map { $0 >= today } ?? false) }
    }

    private var regulars: [QuestEvent] { Content.shared.events.filter { $0.spot == spot.id } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EVENTS").font(.caption.weight(.heavy)).tracking(1.5).foregroundStyle(theme.accent)
                        Text(spot.n).font(.title2.weight(.bold)).foregroundStyle(theme.text)
                        Text(spot.a).font(.subheadline).foregroundStyle(theme.muted)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(theme.text)
                            .frame(width: 36, height: 36).background(theme.raised, in: Circle())
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                }
                ForEach(live) { event in
                    row(pill: event.when, colour: theme.fill, title: event.title, detail: event.note, link: event.url)
                }
                ForEach(regulars) { event in
                    row(pill: event.when, colour: Color(css: event.color), title: event.title, detail: event.d, link: nil)
                }
                if live.isEmpty && regulars.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No dates listed here yet.").font(.headline).foregroundStyle(theme.text)
                        Text("New ones land on the Quest board as soon as they're posted.")
                            .font(.subheadline).foregroundStyle(theme.muted)
                        if let site = spot.discoverPage?.links?.first, let url = site.link {
                            Button("Check \(site.title)") { reading = url }.buttonStyle(OutlineButton()).padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(16)
        }
        .background(theme.bg.ignoresSafeArea())
        .sheet(item: $reading) { WebPage(url: $0).ignoresSafeArea() }
    }

    private func row(pill: String, colour: Color, title: String, detail: String?, link: URL?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pill).font(.caption.weight(.bold)).foregroundStyle(Color.ink)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(colour, in: Capsule())
            Text(title).font(.title3.weight(.bold)).foregroundStyle(theme.text).padding(.top, 4)
            if let detail {
                Text(detail).font(.subheadline).foregroundStyle(theme.text)
            }
            if let link {
                Button("Details") { reading = link }.buttonStyle(OutlineButton()).padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
