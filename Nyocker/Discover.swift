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
        /// Words on the page background; paper if not set.
        let text: String?
        /// Bullets on the cards; gold if not set.
        let mark: String?
    }

    /// The page's own look. Every key is optional: the defaults are the Kerge page.
    struct Style: Decodable {
        let font: String?
        let caps: Bool?
        let corner: Double?
        let shadow: String?
        let frame: Bool?
        let pattern: String?
        let ornament: String?
        let tilt: Double?
        /// The venue's own logo, mirrored to the feed site (https only).
        let logo: String?
        let logoBg: String?
        let logoShape: String?

        static let kerge = Style(font: nil, caps: nil, corner: nil, shadow: nil, frame: nil, pattern: nil,
                                 ornament: nil, tilt: nil, logo: nil, logoBg: nil, logoShape: nil)

        var design: Font.Design {
            switch font {
            case "rounded": return .rounded
            case "mono": return .monospaced
            case "default": return .default
            default: return .serif
            }
        }

        var logoURL: URL? { logo.flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil } }
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
    let style: Style?

    var look: Style { style ?? .kerge }

    private enum CodingKeys: String, CodingKey {
        case place, title, subtitle, note, hero, intro, listTitle, numbered, lines, closing, art, links, sources, colors, style
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

    private var look: DiscoverPage.Style { page.look }
    private var paper: Color { Color(css: page.colors.paper) }
    private var brick: Color { Color(css: page.colors.brick) }
    private var deep: Color { Color(css: page.colors.deep) }
    private var gold: Color { Color(css: page.colors.gold) }
    private var text: Color { Color(css: page.colors.text ?? page.colors.paper) }
    private var mark: Color { Color(css: page.colors.mark ?? page.colors.gold) }

    private var design: Font.Design { look.design }
    private var corner: CGFloat { CGFloat(look.corner ?? 6) }
    private var ornament: String { look.ornament ?? "✶" }
    private var card: RoundedRectangle { RoundedRectangle(cornerRadius: corner, style: .continuous) }

    private static let numerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    if let hero = page.hero {
                        Image(hero).resizable().scaledToFit()
                            .accessibilityLabel("\(spot.n) logo")
                    } else {
                        emblem.padding(.top, 64).padding(.bottom, 20)
                    }
                    VStack(spacing: 22) {
                        heading
                        paperCard { lines(page.intro, big: true) }
                        if let title = page.listTitle {
                            Text(title.uppercased()).font(.system(.caption, design: design).weight(.heavy)).tracking(1.5)
                                .foregroundStyle(text.opacity(0.85)).frame(maxWidth: .infinity, alignment: .leading)
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
            .background(PagePattern(kind: look.pattern ?? "none", ink: text).background(brick).ignoresSafeArea())

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

    /// The venue's own logo when it publishes one, otherwise its category sign.
    @ViewBuilder private var emblem: some View {
        if let url = look.logoURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    logoFrame(image.resizable().scaledToFit())
                } else if phase.error != nil {
                    badge
                } else {
                    logoFrame(ProgressView().tint(deep))
                }
            }
            .accessibilityLabel("\(spot.n) logo")
        } else {
            badge
        }
    }

    private func logoFrame<Inner: View>(_ inner: Inner) -> some View {
        let fill = look.logoBg.map { Color(css: $0) } ?? paper
        let shape = look.logoShape ?? "circle"
        let wide = shape == "wide"
        return inner
            .padding(wide ? 18 : 20)
            .frame(width: wide ? 240 : 132, height: wide ? 110 : 132)
            .background(fill, in: RoundedRectangle(cornerRadius: shape == "circle" ? 66 : min(corner, 18), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: shape == "circle" ? 74 : min(corner, 18) + 6, style: .continuous)
                .stroke(text.opacity(0.55), lineWidth: 2).padding(-8))
            .shadow(color: .black.opacity(look.shadow == "none" ? 0 : 0.25), radius: 0, x: 4, y: 4)
    }

    private var badge: some View {
        ZStack {
            Circle().fill(gold).frame(width: 96, height: 96)
            Circle().stroke(text.opacity(0.6), lineWidth: 2).frame(width: 112, height: 112)
            Image(systemName: spot.category.symbol).font(.system(size: 40, weight: .bold))
                .foregroundStyle(deep)
        }
        .accessibilityHidden(true)
    }

    private func headline(_ string: String) -> String { look.caps == true ? string.uppercased() : string }

    private var heading: some View {
        VStack(spacing: 8) {
            Text(page.place).font(.system(.caption, design: design).weight(.bold)).tracking(1.5)
                .foregroundStyle(text.opacity(0.85))
                .multilineTextAlignment(.center)
            Text(headline(page.title)).font(.system(size: look.caps == true ? 28 : 30, weight: .black, design: design))
                .tracking(look.caps == true ? 1 : 0)
                .multilineTextAlignment(.center).foregroundStyle(text)
            Text(page.subtitle).font(.system(.subheadline, design: design).italic()).foregroundStyle(text.opacity(0.8))
                .multilineTextAlignment(.center)
            if let note = page.note {
                HStack(alignment: .top, spacing: 8) {
                    Text("e").font(.system(size: 22, weight: .black, design: .serif)).foregroundStyle(deep)
                        .frame(width: 34, height: 34).background(gold, in: Circle())
                    Text(note).font(.footnote).foregroundStyle(text)
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
        let shadow = look.shadow ?? "hard"
        return inner()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(paper, in: card)
            .overlay(RoundedRectangle(cornerRadius: max(corner - 3, 0), style: .continuous)
                .stroke(deep.opacity(look.frame == false ? 0 : 0.25), lineWidth: 1).padding(5))
            .overlay(card.stroke(deep, lineWidth: shadow == "hard" && look.frame == false ? 2 : 0))
            .shadow(color: deep.opacity(shadow == "hard" ? (look.frame == false ? 0.9 : 0.35) : shadow == "soft" ? 0.22 : 0),
                    radius: shadow == "soft" ? 10 : 0, x: shadow == "soft" ? 0 : 4, y: 4)
    }

    private func lines(_ line: DiscoverPage.Line, big: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(line.text).font(.system(size: big ? 19 : 17, weight: big ? .semibold : .regular, design: design))
                .foregroundStyle(deep)
            if let english = line.english {
                Text(english).font(.footnote).foregroundStyle(deep.opacity(0.7))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func lineCard(_ index: Int, _ line: DiscoverPage.Line) -> some View {
        paperCard {
            HStack(alignment: .top, spacing: 14) {
                if page.numbered == true {
                    Text(Self.numerals[min(index, Self.numerals.count - 1)])
                        .font(.system(size: 15, weight: .black, design: design)).foregroundStyle(deep)
                        .frame(width: 38, height: 38).background(gold, in: Circle())
                        .accessibilityLabel("Rule \(index + 1)")
                } else if look.ornament != nil {
                    Text(ornament).font(.system(size: 15, weight: .black)).foregroundStyle(mark)
                        .frame(width: 16).padding(.top, 2).accessibilityHidden(true)
                } else {
                    Circle().fill(mark).frame(width: 12, height: 12).padding(.top, 6).accessibilityHidden(true)
                }
                lines(line)
            }
        }
    }

    private func art(_ art: DiscoverPage.Art) -> some View {
        HStack {
            if !art.leading { Spacer() }
            Image(art.image).renderingMode(.template).resizable().scaledToFit()
                .foregroundStyle(text)
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
            Text(ornament).font(.title2).foregroundStyle(deep.opacity(0.6))
            Text(closing.text).font(.system(size: 21, weight: .black, design: design))
                .multilineTextAlignment(.center).foregroundStyle(deep)
            if let english = closing.english {
                Text(english).font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center).foregroundStyle(deep.opacity(0.75))
            }
            if let note = closing.note {
                Text(note).font(.caption.italic()).foregroundStyle(deep.opacity(0.65))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(gold, in: card)
        .overlay(RoundedRectangle(cornerRadius: max(corner - 3, 0), style: .continuous).stroke(deep, lineWidth: 2).padding(6))
        .rotationEffect(.degrees(look.tilt ?? -1.5))
        .padding(.top, 8)
    }

    private var actions: some View {
        let radius = min(max(corner, 4), 24)
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    dismiss()
                    directions()
                } label: {
                    Label("Directions", systemImage: "figure.walk")
                }
                .buttonStyle(BrandButton(fill: paper, ink: deep, radius: radius))
                if let link = spot.eventsLink {
                    Button { reading = link } label: { Label("Events", systemImage: "calendar") }
                        .buttonStyle(BrandButton(fill: deep, ink: paper, radius: radius))
                }
            }
            ForEach(page.links ?? []) { item in
                if let url = item.link {
                    Button { reading = url } label: { Label(item.title, systemImage: "arrow.up.right.square") }
                        .buttonStyle(BrandButton(fill: gold, ink: deep, radius: radius))
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder private var footer: some View {
        if let sources = page.sources {
            Text("Sources: \(sources)").font(.caption).foregroundStyle(text.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A faint texture behind a Discover page, drawn in the page's text colour.
struct PagePattern: View {
    let kind: String
    let ink: Color

    var body: some View {
        Canvas { context, size in
            let shade = GraphicsContext.Shading.color(ink.opacity(0.07))
            var path = Path()
            switch kind {
            case "dots":
                stride(from: CGFloat(9), to: size.height, by: 18).forEach { y in
                    stride(from: CGFloat(9), to: size.width, by: 18).forEach { x in
                        path.addEllipse(in: CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2))
                    }
                }
                context.fill(path, with: shade)
                return
            case "stripes":
                stride(from: -size.height, to: size.width, by: 16).forEach { x in
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                }
            case "grid":
                stride(from: CGFloat(0), to: size.width, by: 22).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: CGFloat(0), to: size.height, by: 22).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
                }
            case "rays":
                let centre = CGPoint(x: size.width / 2, y: 120)
                let reach = max(size.width, size.height) * 1.5
                stride(from: 0.0, to: 360.0, by: 7.5).forEach { degrees in
                    let angle = degrees * .pi / 180
                    path.move(to: centre)
                    path.addLine(to: CGPoint(x: centre.x + reach * CGFloat(cos(angle)), y: centre.y + reach * CGFloat(sin(angle))))
                }
            case "waves":
                stride(from: CGFloat(20), to: size.height, by: 34).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    stride(from: CGFloat(0), through: size.width, by: 6).forEach { x in
                        path.addLine(to: CGPoint(x: x, y: y + 6 * CGFloat(sin(Double(x) / 22))))
                    }
                }
            case "diamonds":
                stride(from: CGFloat(0), to: size.height + 28, by: 28).forEach { y in
                    stride(from: CGFloat(0), to: size.width + 28, by: 28).forEach { x in
                        path.move(to: CGPoint(x: x, y: y - 9))
                        path.addLine(to: CGPoint(x: x + 9, y: y))
                        path.addLine(to: CGPoint(x: x, y: y + 9))
                        path.addLine(to: CGPoint(x: x - 9, y: y))
                        path.closeSubpath()
                    }
                }
            default:
                return
            }
            context.stroke(path, with: shade, lineWidth: 1.2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A filled button in a venue's own colours.
struct BrandButton: ButtonStyle {
    let fill: Color
    let ink: Color
    var radius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
