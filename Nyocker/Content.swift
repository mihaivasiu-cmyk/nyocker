import CoreLocation
import Foundation
import SwiftUI

struct Spot: Decodable, Identifiable, Hashable {
    let id: String
    let c: String
    let n: String
    let a: String
    let d: String
    let lat: Double
    let lon: Double
    let when: String?
    let src: String?
    let old: Bool?
    /// Asset name of the venue's own pin art, drawn instead of the category symbol.
    let icon: String?
    /// The venue's programme, opened inside the app.
    let events: String?
    /// Key of a page in `DiscoverPage.all`.
    let discover: String?

    var category: Category { Category(rawValue: c) ?? .local }
    var eventsLink: URL? { events.flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil } }
    var discoverPage: DiscoverPage? { discover.flatMap { DiscoverPage.all[$0] } }
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
    var tag: String { when.map { "LORE / \($0)" } ?? category.tag }
}

struct QuestEvent: Decodable, Identifiable {
    let id: String
    let title: String
    let place: String
    let spot: String
    let when: String
    let color: String
    let d: String
}

struct Release: Decodable, Identifiable {
    let artist: String
    let release: String
    let meta: String
    let color: String
    let url: String
    let player: String

    var id: String { player }
    var link: URL { URL(string: url)! }
}

struct Content: Decodable {
    let spots: [Spot]
    let events: [QuestEvent]
    let radio: [Release]

    static let shared: Content = {
        let url = Bundle.main.url(forResource: "content", withExtension: "json")!
        return try! JSONDecoder().decode(Content.self, from: Data(contentsOf: url))
    }()
}

extension Color {
    init(css: String) {
        self.init(hex: UInt32(css.dropFirst(), radix: 16) ?? 0xFFFFFF)
    }
}

/// Things the viewer has marked, kept on this device only.
final class Progress: ObservableObject {
    @Published var found: Set<String> { didSet { save(found, "found") } }
    @Published var going: Set<String> { didSet { save(going, "going") } }

    init() {
        found = Set(UserDefaults.standard.stringArray(forKey: "found") ?? [])
        going = Set(UserDefaults.standard.stringArray(forKey: "going") ?? [])
    }

    private func save(_ value: Set<String>, _ key: String) {
        UserDefaults.standard.set(Array(value), forKey: key)
    }

    func toggle(_ id: String, in keyPath: ReferenceWritableKeyPath<Progress, Set<String>>) {
        if self[keyPath: keyPath].contains(id) {
            self[keyPath: keyPath].remove(id)
        } else {
            self[keyPath: keyPath].insert(id)
        }
    }
}
