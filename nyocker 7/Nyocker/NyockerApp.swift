import SwiftUI

enum Tab: Hashable {
    case map, events, news, radio
}

@main
struct NyockerApp: App {
    @StateObject private var progress = Progress()
    @StateObject private var clock = ThemeClock()
    @StateObject private var news = NewsStore(name: "news")
    @StateObject private var events = EventStore(name: "events", allowEmpty: true)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(phase: clock.phase)
                .environmentObject(progress)
                .environmentObject(news)
                .environmentObject(events)
                .environment(\.theme, clock.phase.palette)
                .preferredColorScheme(clock.phase.palette.scheme)
                .tint(clock.phase.palette.accent)
                .task { await refreshFeeds() }
                .onChange(of: scenePhase) { scene in
                    guard scene == .active else { return }
                    clock.refresh()
                    Task { await refreshFeeds() }
                }
        }
    }

    private func refreshFeeds() async {
        await news.refresh()
        await events.refresh()
    }
}

struct RootView: View {
    let phase: DayPhase
    @State private var started = RootView.previewTab != nil
    @State private var tab: Tab = RootView.previewTab ?? .map
    @State private var selected: Spot?

    /// Launch with `-NyockerTab radio` to skip the start screen while testing.
    private static var previewTab: Tab? {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "NyockerTab") {
        case "map": return .map
        case "events": return .events
        case "news": return .news
        case "radio": return .radio
        default: return nil
        }
        #else
        return nil
        #endif
    }

    var body: some View {
        if started {
            TabView(selection: $tab) {
                MapScreen(selected: $selected)
                    .tabItem { Label("Map", systemImage: "map") }.tag(Tab.map)
                EventsScreen { spot in
                    selected = spot
                    tab = .map
                }
                .tabItem { Label("Events", systemImage: "calendar") }.tag(Tab.events)
                NewsScreen()
                    .tabItem { Label("News", systemImage: "newspaper") }.tag(Tab.news)
                RadioScreen()
                    .tabItem { Label("Radio", systemImage: "radio") }.tag(Tab.radio)
            }
        } else {
            StartScreen(phase: phase) { withAnimation { started = true } }
        }
    }
}

struct StartScreen: View {
    @Environment(\.theme) private var theme
    let phase: DayPhase
    let start: () -> Void

    private var tally: String {
        let lore = Content.shared.spots.filter { $0.category == .lore }.count
        return "\(Content.shared.spots.count - lore) spots. \(lore) legends. 1 car eaten by a street."
    }

    var body: some View {
        ZStack {
            DayScene(palette: theme).ignoresSafeArea()
            VStack(spacing: 8) {
                Label(phase.title.uppercased(), systemImage: phase.symbol)
                    .font(.footnote.weight(.semibold)).foregroundStyle(theme.skyInk)
                Text("Nyócker").font(.system(size: 68, weight: .bold)).foregroundStyle(theme.skyInk)
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text("the guide the district never approved").font(.body).foregroundStyle(theme.skyInk)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Press start", action: start).buttonStyle(PrimaryButton())
                Text(tally).font(.footnote).foregroundStyle(Color.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 14)
        }
    }
}

/// The start screen's city, redrawn for the time of day.
struct DayScene: View {
    let palette: Palette

    private struct Block {
        let x, width, height: Double
        let far: Bool
        var lit: [(x: Double, y: Double)]
    }

    /// A fixed skyline, so the city stays the same from one launch to the next.
    private static let blocks: [Block] = {
        var seed: UInt32 = 8
        func next(_ range: ClosedRange<Double>) -> Double {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return range.lowerBound + (range.upperBound - range.lowerBound) * Double(seed >> 16) / 65535
        }
        var out: [Block] = []
        for far in [true, false] {
            var x = far ? -6.0 : -14.0
            while x < 460 {
                let width = far ? next(36...66) : next(44...76)
                let height = far ? next(120...230) : next(70...150)
                var lit: [(Double, Double)] = []
                if !far {
                    for wy in stride(from: 12.0, to: height - 12, by: 16) {
                        for wx in stride(from: 8.0, to: width - 12, by: 13) where next(0...1) < 0.36 {
                            lit.append((wx, wy))
                        }
                    }
                }
                out.append(Block(x: x, width: width, height: height, far: far, lit: lit))
                x += width + (far ? 3 : 4)
            }
        }
        return out
    }()

    private static let stars: [(x: Double, y: Double, r: Double)] = {
        var seed: UInt32 = 42
        func next() -> Double {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return Double(seed >> 16) / 65535
        }
        return (0..<56).map { _ in (next(), next() * 0.5, 0.6 + next()) }
    }()

    /// Holds the top colour long enough for the title to stay readable over it.
    private var skyStops: [Gradient.Stop] {
        let spots: [CGFloat] = palette.sky.count == 4 ? [0.05, 0.5, 0.64, 0.78] : [0.05, 0.5, 0.78]
        return zip(palette.sky, spots).map { Gradient.Stop(color: $0, location: $1) }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let horizon = h * 0.77
            ZStack(alignment: .topLeading) {
                LinearGradient(stops: skyStops, startPoint: .top, endPoint: .bottom)
                Canvas { ctx, size in
                    for s in Self.stars {
                        ctx.fill(Path(ellipseIn: CGRect(x: s.x * size.width, y: s.y * size.height, width: s.r * 2, height: s.r * 2)), with: .color(.white))
                    }
                }
                .opacity(palette.stars)
                Circle().fill(palette.body)
                    .frame(width: 60, height: 60)
                    .shadow(color: palette.body.opacity(0.7), radius: palette.moon ? 8 : 26)
                .position(x: w * 0.78, y: h * palette.bodyY)
                Canvas { ctx, _ in
                    let scale = w / 390
                    for b in Self.blocks where b.far == true {
                        let top = horizon - b.height * scale
                        ctx.fill(Path(roundedRect: CGRect(x: b.x * scale, y: top, width: b.width * scale, height: b.height * scale + 2), cornerRadius: 3), with: .color(palette.far))
                    }
                    for b in Self.blocks where b.far == false {
                        let top = horizon - b.height * scale
                        ctx.fill(Path(roundedRect: CGRect(x: b.x * scale, y: top, width: b.width * scale, height: b.height * scale + 2), cornerRadius: 3), with: .color(palette.near))
                        for l in b.lit {
                            ctx.fill(Path(roundedRect: CGRect(x: (b.x + l.x) * scale, y: top + l.y * scale, width: 6 * scale, height: 8 * scale), cornerRadius: 1),
                                     with: .color(Color(hex: 0xFFD166).opacity(palette.windows)))
                        }
                    }
                    // Keleti's arched front, with its glass lit behind the tram.
                    let cx = w / 2, half = 75 * scale, spring = horizon - 60 * scale
                    let arch = Path { p in
                        p.move(to: CGPoint(x: cx - half, y: horizon))
                        p.addLine(to: CGPoint(x: cx - half, y: spring))
                        p.addArc(center: CGPoint(x: cx, y: spring), radius: half, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                        p.addLine(to: CGPoint(x: cx + half, y: horizon))
                        p.closeSubpath()
                    }
                    ctx.fill(arch, with: .color(palette.ground))
                    for x in stride(from: -56.0, through: 56, by: 14) {
                        ctx.fill(Path(roundedRect: CGRect(x: cx + x * scale - 1.5, y: spring - 34 * scale, width: 3, height: 34 * scale), cornerRadius: 1.5),
                                 with: .color(Color(hex: 0x4CC9F0).opacity(0.8)))
                    }
                }
                Rectangle().fill(palette.ground).frame(height: h - horizon).offset(y: horizon)
                Tram(lit: palette.windows > 0.5)
                    .frame(width: w * 0.76, height: w * 0.76 * 24 / 99)
                    .position(x: w / 2, y: horizon - w * 0.76 * 24 / 99 / 2 + 8)
            }
        }
    }
}

/// The 4-6 tram, the last bit of pixel art in the app.
struct Tram: View {
    let lit: Bool

    var body: some View {
        Canvas { ctx, size in
            let u = size.width / 99
            func block(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ hex: UInt32) {
                ctx.fill(Path(CGRect(x: x * u, y: y * u, width: w * u, height: h * u)), with: .color(Color(hex: hex)))
            }
            block(0, 0, 99, 21, 0xF8B800)
            block(0, 0, 99, 2, 0xF8F8F8)
            block(0, 14, 99, 7, 0xC87800)
            for x in stride(from: 4.0, to: 96, by: 12) {
                block(x, 4, 9, 8, lit ? 0xFFE08A : 0x18285F)
            }
            block(38, 4, 5, 15, 0x785000)
            block(70, 4, 5, 15, 0x785000)
            for x in [10.0, 30, 62, 86] {
                block(x, 21, 6, 3, 0x0D0B1E)
            }
        }
        .accessibilityHidden(true)
    }
}
