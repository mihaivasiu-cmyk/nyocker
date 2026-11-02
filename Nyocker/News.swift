import SwiftUI

struct Story: Codable, Identifiable {
    let id: String
    let title: String
    let source: String
    let url: String
    let date: String

    var link: URL? {
        guard let link = URL(string: url), link.scheme == "https" else { return nil }
        return link
    }

    var published: Date? { ISO8601DateFormatter().date(from: date) }
}

struct LiveFeed<Item: Codable>: Codable {
    let version: Int
    let updated: String
    let items: [Item]

    var updatedAt: Date? { ISO8601DateFormatter().date(from: updated) }
}

typealias NewsStore = FeedStore<Story>
typealias EventStore = FeedStore<LiveEvent>

/// Shows saved items at once, then swaps in the live feed when it arrives.
@MainActor
final class FeedStore<Item: Codable>: ObservableObject {
    @Published private(set) var feed: LiveFeed<Item>
    @Published private(set) var loading = false
    @Published private(set) var offline = false
    private var lastTry: Date?
    private let name: String
    private let allowEmpty: Bool

    private var cache: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("\(name).json")
    }

    private var source: URL? {
        var base = Bundle.main.object(forInfoDictionaryKey: "NyockerFeedBase") as? String
        #if DEBUG
        // Launch with `-NyockerFeedBase http://localhost:8809` to test local feeds.
        base = UserDefaults.standard.string(forKey: "NyockerFeedBase") ?? base
        #endif
        return base.flatMap { $0.isEmpty ? nil : URL(string: "\($0)/\(name).json") }
    }

    private static func decode(_ data: Data, allowEmpty: Bool) -> LiveFeed<Item>? {
        guard let feed = try? JSONDecoder().decode(LiveFeed<Item>.self, from: data),
              feed.version == 1, allowEmpty || !feed.items.isEmpty else { return nil }
        return feed
    }

    /// An empty list can be right for events, but never for news.
    init(name: String, allowEmpty: Bool = false) {
        self.name = name
        self.allowEmpty = allowEmpty
        let saved = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("\(name).json")
        let seed = Bundle.main.url(forResource: "\(name)-seed", withExtension: "json")!
        feed = (try? Data(contentsOf: saved)).flatMap { Self.decode($0, allowEmpty: allowEmpty) }
            ?? Self.decode(try! Data(contentsOf: seed), allowEmpty: true)!
    }

    /// Reopening the app often should not hit the feed each time; the button always does.
    func refresh(force: Bool = false) async {
        guard let source, !loading else { return }
        if !force, let lastTry, Date().timeIntervalSince(lastTry) < 600 { return }
        lastTry = Date()
        loading = true
        defer { loading = false }
        var request = URLRequest(url: source, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let fresh = Self.decode(data, allowEmpty: allowEmpty) else {
                offline = true
                return
            }
            feed = fresh
            offline = false
            try? data.write(to: cache, options: .atomic)
        } catch {
            offline = true
        }
    }
}

struct NewsScreen: View {
    @EnvironmentObject private var news: NewsStore
    @Environment(\.theme) private var theme
    @State private var reading: URL?

    private var status: String {
        if news.offline { return "Offline. Showing saved stories." }
        guard let updated = news.feed.updatedAt else { return "Local news from the district." }
        return "Updated \(RelativeDateTimeFormatter().localizedString(for: updated, relativeTo: Date()))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    ScreenTitle(title: "The Nyócker Times", subtitle: status)
                    Button { Task { await news.refresh(force: true) } } label: {
                        Group {
                            if news.loading {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise").font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundStyle(theme.accent)
                        .frame(width: 44, height: 44)
                    }
                    .disabled(news.loading)
                    .accessibilityLabel("Refresh news")
                }
                ForEach(news.feed.items) { story in
                    Button { reading = story.link } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(story.source)
                                Spacer()
                                if let date = story.published {
                                    Text(date, format: .dateTime.day().month(.abbreviated))
                                }
                            }
                            .font(.caption.weight(.bold)).foregroundStyle(theme.muted)
                            Text(story.title).font(.headline).foregroundStyle(theme.text)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(16)
        }
        .background(theme.bg.ignoresSafeArea())
        .sheet(item: $reading) { WebPage(url: $0).ignoresSafeArea() }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
