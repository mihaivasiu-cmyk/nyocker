import SwiftUI

/// A spot's own page: its story, its colours and, for some venues, their own art.
/// Pages live in discover.json, which the desktop app reads too.
struct DiscoverPage: Decodable, Identifiable {
    struct Line: Decodable {
        let text: String
        let english: String?
    }

    struct Closing: Decodable {
        let text: String
        let english: String?
        let note: String?
    }

    /// A piece of the venue's art, placed after one of the lines.
    struct Art: Decodable {
        let image: String
        let afterLine: Int
        let leading: Bool
        let tilt: Double
    }

    struct Link: Decodable, Identifiable {
        let title: String
        let url: String

        var id: String { url }
        var link: URL? { URL(string: url).flatMap { $0.scheme == "https" ? $0 : nil } }
    }

    struct Colors: Decodable {
        let paper, brick, deep, gold: String
    }

    var id = ""
    let place: String
    let title: String
    let subtitle: String
    let note: String?
    let hero: String?
    let intro: Line
    let listTitle: String?
    let numbered: Bool?
    let lines: [Line]
    let closing: Closing?
    let art: [Art]?
    let links: [Link]?
    let sources: String?
    let colors: Colors

    private enum CodingKeys: String, CodingKey {
        case place, title, subtitle, note, hero, intro, listTitle, numbered, lines, closing, art, links, sources, colors
    }

    static let all: [String: DiscoverPage] = {
        guard let url = Bundle.main.url(forResource: "discover", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let pages = try? JSONDecoder().decode([String: DiscoverPage].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: pages.map { key, page in
            var page = page
            page.id = key
            return (key, page)
        })
    }()
}

struct DiscoverScreen: View {
    @Environment(\.dismiss) private var dismiss
    let page: DiscoverPage
    let spot: Spot
    let directions: () -> Void
    @State private var reading: URL?

    private var paper: Color { Color(css: page.colors.paper) }
    private var brick: Color { Color(css: page.colors.brick) }
    private var deep: Color { Color(css: page.colors.deep) }
    private var gold: Color { Color(css: page.colors.gold) }

    private static let numerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    if let hero = page.hero {
                        Image(hero).resizable().scaledToFit()
                            .accessibilityLabel("\(spot.n) logo")
                    } else {
                        badge.padding(.top, 64).padding(.bottom, 20)
                    }
                    VStack(spacing: 22) {
                        heading
                        paperCard { lines(page.intro, big: true) }
                        if let title = page.listTitle {
                            Text(title.uppercased()).font(.caption.weight(.heavy)).tracking(1.5)
                                .foregroundStyle(gold).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, -10)
                        }
                        ForEach(Array(page.lines.enumerated()), id: \.offset) { index, line in
                            lineCard(index, line)
                            ForEach((page.art ?? []).filter { $0.afterLine == index }, id: \.image) { art($0) }
                        }
                        if let closing = page.closing { closingCard(closing) }
                        actions
                        footer
                    }
                    .padding(.horizontal, 18).padding(.bottom, 40)
                }
            }
            .background(brick.ignoresSafeArea())

            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(deep)
                    .frame(width: 36, height: 36).background(paper, in: Circle())
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close")
            .padding(.trailing, 10).padding(.top, 10)
        }
        .sheet(item: $reading) { WebPage(url: $0).ignoresSafeArea() }
    }

    /// Spots without art of their own get their category sign, large.
    private var badge: some View {
        ZStack {
            Circle().fill(gold).frame(width: 96, height: 96)
            Circle().stroke(paper.opacity(0.6), lineWidth: 2).frame(width: 112, height: 112)
            Image(systemName: spot.category.symbol).font(.system(size: 40, weight: .bold))
                .foregroundStyle(spot.category == .lore ? .white : Color.ink)
        }
        .accessibilityHidden(true)
    }

    private var heading: some View {
        VStack(spacing: 8) {
            Text(page.place).font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(gold)
                .multilineTextAlignment(.center)
            Text(page.title).font(.system(size: 30, weight: .black, design: .serif))
                .multilineTextAlignment(.center).foregroundStyle(paper)
            Text(page.subtitle).font(.subheadline.italic()).foregroundStyle(paper.opacity(0.8))
                .multilineTextAlignment(.center)
            if let note = page.note {
                HStack(alignment: .top, spacing: 8) {
                    Text("e").font(.system(size: 22, weight: .black, design: .serif)).foregroundStyle(deep)
                        .frame(width: 34, height: 34).background(gold, in: Circle())
                    Text(note).font(.footnote).foregroundStyle(paper)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(deep.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                .padding(.top, 6)
            }
        }
        .padding(.top, 4)
    }

    private func paperCard<Inner: View>(@ViewBuilder _ inner: () -> Inner) -> some View {
        inner()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(paper, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(deep.opacity(0.25), lineWidth: 1).padding(5))
            .shadow(color: deep.opacity(0.35), radius: 0, x: 4, y: 4)
    }

    private func lines(_ line: DiscoverPage.Line, big: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(line.text).font(.system(size: big ? 19 : 17, weight: big ? .semibold : .regular, design: .serif))
                .foregroundStyle(deep)
            if let english = line.english {
                Text(english).font(.footnote).foregroundStyle(deep.opacity(0.65))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func lineCard(_ index: Int, _ line: DiscoverPage.Line) -> some View {
        paperCard {
            HStack(alignment: .top, spacing: 14) {
                if page.numbered == true {
                    Text(Self.numerals[min(index, Self.numerals.count - 1)])
                        .font(.system(size: 15, weight: .black, design: .serif)).foregroundStyle(deep)
                        .frame(width: 38, height: 38).background(gold, in: Circle())
                        .accessibilityLabel("Rule \(index + 1)")
                } else {
                    Circle().fill(gold).frame(width: 12, height: 12).padding(.top, 6).accessibilityHidden(true)
                }
                lines(line)
            }
        }
    }

    private func art(_ art: DiscoverPage.Art) -> some View {
        HStack {
            if !art.leading { Spacer() }
            Image(art.image).renderingMode(.template).resizable().scaledToFit()
                .foregroundStyle(paper)
                .frame(height: 190)
                .rotationEffect(.degrees(art.tilt))
                .accessibilityHidden(true)
            if art.leading { Spacer() }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, -6)
    }

    private func closingCard(_ closing: DiscoverPage.Closing) -> some View {
        VStack(spacing: 10) {
            Text("✶").font(.title2).foregroundStyle(deep.opacity(0.6))
            Text(closing.text).font(.system(size: 21, weight: .black, design: .serif))
                .multilineTextAlignment(.center).foregroundStyle(deep)
            if let english = closing.english {
                Text(english).font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center).foregroundStyle(deep.opacity(0.75))
            }
            if let note = closing.note {
                Text(note).font(.caption.italic()).foregroundStyle(deep.opacity(0.6))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(gold, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(deep, lineWidth: 2).padding(6))
        .rotationEffect(.degrees(-1.5))
        .padding(.top, 8)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    dismiss()
                    directions()
                } label: {
                    Label("Directions", systemImage: "figure.walk")
                }
                .buttonStyle(BrandButton(fill: paper, ink: deep))
                if let link = spot.eventsLink {
                    Button { reading = link } label: { Label("Events", systemImage: "calendar") }
                        .buttonStyle(BrandButton(fill: deep, ink: paper))
                }
            }
            ForEach(page.links ?? []) { item in
                if let url = item.link {
                    Button { reading = url } label: { Label(item.title, systemImage: "arrow.up.right.square") }
                        .buttonStyle(BrandButton(fill: deep.opacity(0.55), ink: paper))
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder private var footer: some View {
        if let sources = page.sources {
            Text("Sources: \(sources)").font(.caption).foregroundStyle(paper.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A filled button in a venue's own colours.
struct BrandButton: ButtonStyle {
    let fill: Color
    let ink: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(fill, in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
