import Combine
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// Text on bright fills, whatever the time of day.
    static let ink = Color(hex: 0x100E26)
    static let mint = Color(hex: 0x5BE37D)
}

/// The app's look at each moment of the day, by the clock on the phone.
enum DayPhase: String, CaseIterable {
    case dawn, sunrise, morning, midday, golden, sunset, dusk, night

    /// Minutes after midnight at which each phase begins.
    private static let starts: [(minute: Int, phase: DayPhase)] = [
        (4 * 60 + 30, .dawn), (5 * 60 + 30, .sunrise), (7 * 60 + 30, .morning), (11 * 60, .midday),
        (16 * 60, .golden), (18 * 60 + 30, .sunset), (20 * 60, .dusk), (21 * 60 + 30, .night),
    ]

    static func at(minute: Int) -> DayPhase {
        starts.last { $0.minute <= minute }?.phase ?? .night
    }

    var title: String {
        switch self {
        case .dawn: "First light"
        case .sunrise: "Sunrise"
        case .morning: "Morning"
        case .midday: "Midday"
        case .golden: "Golden hour"
        case .sunset: "Sunset"
        case .dusk: "Dusk"
        case .night: "Night"
        }
    }

    var symbol: String {
        switch self {
        case .dawn: "sun.haze.fill"
        case .sunrise: "sunrise.fill"
        case .morning, .midday: "sun.max.fill"
        case .golden: "sun.haze.fill"
        case .sunset: "sunset.fill"
        case .dusk, .night: "moon.stars.fill"
        }
    }

    var palette: Palette {
        switch self {
        case .dawn:
            Palette(scheme: .dark, bg: 0x1D1A4A, surface: 0x2D2966, raised: 0x423C85, line: 0x7A74BF, text: 0xFFFFFF,
                    muted: 0xD6D2F0, accent: 0xFFB8C9, link: 0xB8DCFF, lore: 0x3A2F86, fill: 0xFFB8C9,
                    sky: [0x12103A, 0x3B2A78, 0xB4568C], skyInk: 0xFFE4EC, body: 0xFFE9B0, bodyY: 0.60, moon: false,
                    stars: 0.7, windows: 0.8, far: 0x2F2670, near: 0x1B1748, ground: 0x12103A)
        case .sunrise:
            Palette(scheme: .light, bg: 0xFFE8DD, surface: 0xFFF6F1, raised: 0xFFD8C7, line: 0xC98D76, text: 0x3B1730,
                    muted: 0x6E4656, accent: 0xB42A52, link: 0x8A2F6F, lore: 0xFFD8E0, fill: 0xFF9A6B,
                    sky: [0x3A2A7A, 0xD65A8A, 0xFFB56B, 0xFFE59A], skyInk: 0xFFF3C4, body: 0xFFF2B0, bodyY: 0.56, moon: false,
                    stars: 0.15, windows: 0.35, far: 0x7A4A8C, near: 0x4A2A66, ground: 0x2C1A4A)
        case .morning:
            Palette(scheme: .light, bg: 0xE4F3FB, surface: 0xFFFFFF, raised: 0xCDE7F5, line: 0x7FAFC9, text: 0x10304A,
                    muted: 0x3F6078, accent: 0x0A6AA0, link: 0x0A6AA0, lore: 0xD6ECFA, fill: 0xFFD23F,
                    sky: [0x5BB8EC, 0xA8DDF5, 0xE9F6FB], skyInk: 0x0B2A44, body: 0xFFF3C0, bodyY: 0.38, moon: false,
                    stars: 0, windows: 0, far: 0x9CC4DC, near: 0x6C9CBC, ground: 0x34607E)
        case .midday:
            Palette(scheme: .light, bg: 0xFFF6D8, surface: 0xFFFFFF, raised: 0xFFE9A8, line: 0xC4AC5E, text: 0x2B2408,
                    muted: 0x5E5426, accent: 0x8F5400, link: 0x0A6AA0, lore: 0xFFEDB8, fill: 0xFFD23F,
                    sky: [0x4AA9EC, 0x9AD8F7, 0xDFF3FB], skyInk: 0x08233A, body: 0xFFF7D0, bodyY: 0.38, moon: false,
                    stars: 0, windows: 0, far: 0xA4C8DE, near: 0x78A0BC, ground: 0x3E6680)
        case .golden:
            Palette(scheme: .light, bg: 0xFFDFAE, surface: 0xFFF0D6, raised: 0xFFCF8A, line: 0xB88444, text: 0x3D1E08,
                    muted: 0x5E3A18, accent: 0x9A3600, link: 0x7A3A00, lore: 0xFFD39B, fill: 0xFF9E3D,
                    sky: [0xF2A03D, 0xFFC56B, 0xFFE9B0], skyInk: 0x3D1E08, body: 0xFFF3C4, bodyY: 0.44, moon: false,
                    stars: 0, windows: 0.1, far: 0xC48A5A, near: 0x8C5A3C, ground: 0x5C3826)
        case .sunset:
            Palette(scheme: .dark, bg: 0x3B1444, surface: 0x56205E, raised: 0x743078, line: 0xA763A8, text: 0xFFFFFF,
                    muted: 0xF3D6E4, accent: 0xFFB36B, link: 0xFFD0A8, lore: 0x6B1F52, fill: 0xFF9E5E,
                    sky: [0x2A1458, 0xA0357F, 0xFF8A5C, 0xFFC56B], skyInk: 0xFFD23F, body: 0xFFD27A, bodyY: 0.60, moon: false,
                    stars: 0.25, windows: 0.6, far: 0x4A2470, near: 0x2C1648, ground: 0x1E0F36)
        case .dusk:
            Palette(scheme: .dark, bg: 0x17174A, surface: 0x27276A, raised: 0x3A3A8A, line: 0x6C6CC0, text: 0xFFFFFF,
                    muted: 0xD0D0F0, accent: 0xFFC98A, link: 0xB4C6FF, lore: 0x2E2E7E, fill: 0xFFC98A,
                    sky: [0x100E3A, 0x2A1F6E, 0x7A3A8E, 0xD46A6A], skyInk: 0xFFD23F, body: 0xFFE9B0, bodyY: 0.38, moon: true,
                    stars: 0.7, windows: 0.9, far: 0x2A2470, near: 0x191548, ground: 0x100E30)
        case .night:
            Palette(scheme: .dark, bg: 0x100E26, surface: 0x1E1B42, raised: 0x332C66, line: 0x5F58A3, text: 0xFFFFFF,
                    muted: 0xC9C6E4, accent: 0xFFD23F, link: 0xA8E4FA, lore: 0x232A7A, fill: 0xFFD23F,
                    sky: [0x0A0820, 0x1A1650, 0x3A2A7A], skyInk: 0xFFD23F, body: 0xFFE9B0, bodyY: 0.38, moon: true,
                    stars: 1, windows: 1, far: 0x2A1F66, near: 0x191540, ground: 0x100E26)
        }
    }
}

struct Palette {
    let scheme: ColorScheme
    let bg, surface, raised, line, text, muted, accent, link, lore, fill: Color
    let sky: [Color]
    let skyInk, body, far, near, ground: Color
    let bodyY: Double
    let moon: Bool
    let stars, windows: Double

    init(scheme: ColorScheme, bg: UInt32, surface: UInt32, raised: UInt32, line: UInt32, text: UInt32,
         muted: UInt32, accent: UInt32, link: UInt32, lore: UInt32, fill: UInt32,
         sky: [UInt32], skyInk: UInt32, body: UInt32, bodyY: Double, moon: Bool,
         stars: Double, windows: Double, far: UInt32, near: UInt32, ground: UInt32) {
        self.scheme = scheme
        self.bg = Color(hex: bg)
        self.surface = Color(hex: surface)
        self.raised = Color(hex: raised)
        self.line = Color(hex: line)
        self.text = Color(hex: text)
        self.muted = Color(hex: muted)
        self.accent = Color(hex: accent)
        self.link = Color(hex: link)
        self.lore = Color(hex: lore)
        self.fill = Color(hex: fill)
        self.sky = sky.map { Color(hex: $0) }
        self.skyInk = Color(hex: skyInk)
        self.body = Color(hex: body)
        self.bodyY = bodyY
        self.moon = moon
        self.stars = stars
        self.windows = windows
        self.far = Color(hex: far)
        self.near = Color(hex: near)
        self.ground = Color(hex: ground)
    }
}

/// Follows the clock, so a phase change lands even if the app stays open.
final class ThemeClock: ObservableObject {
    @Published private(set) var phase = ThemeClock.current()
    private var timer: AnyCancellable?

    init() {
        timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        let next = Self.current()
        guard next != phase else { return }
        withAnimation(.easeInOut(duration: 2)) { phase = next }
    }

    private static func current() -> DayPhase {
        #if DEBUG
        // Launch with `-NyockerHour 6` to preview any time of day.
        if UserDefaults.standard.object(forKey: "NyockerHour") != nil {
            return .at(minute: Int(UserDefaults.standard.double(forKey: "NyockerHour") * 60))
        }
        #endif
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return .at(minute: (now.hour ?? 0) * 60 + (now.minute ?? 0))
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = DayPhase.night.palette
}

extension EnvironmentValues {
    var theme: Palette {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

enum Category: String, CaseIterable, Identifiable {
    case lore, bar, club, art, eat, thrift, local

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lore: "Lore"
        case .bar: "Bars"
        case .club: "Clubs"
        case .art: "Art"
        case .eat: "Eats"
        case .thrift: "Second hand"
        case .local: "Local"
        }
    }

    var tag: String {
        switch self {
        case .lore: "LORE"
        case .bar: "BAR"
        case .club: "CLUB"
        case .art: "ART SPACE"
        case .eat: "EATS"
        case .thrift: "SECOND HAND"
        case .local: "LOCAL"
        }
    }

    /// Newer symbols fall back on iOS 15, where a missing one would draw a blank pin.
    var symbol: String {
        switch self {
        case .lore: "exclamationmark"
        case .bar: Self.best("wineglass.fill", or: "cup.and.saucer.fill")
        case .club: "waveform"
        case .art: "photo.artframe"
        case .eat: "fork.knife"
        case .thrift: Self.best("hanger", or: "tshirt.fill")
        case .local: "house.fill"
        }
    }

    private static func best(_ symbol: String, or fallback: String) -> String {
        UIImage(systemName: symbol) == nil ? fallback : symbol
    }

    var hex: UInt32 {
        switch self {
        case .lore: 0xE8341C
        case .bar: 0xF8B800
        case .club: 0xFF5FA2
        case .art: 0x4CC9F0
        case .eat: 0xFF7A59
        case .thrift: 0x5BE37D
        case .local: 0xE6E3F6
        }
    }

    var color: Color { Color(hex: hex) }
    var ink: Color { self == .lore ? .white : .ink }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.theme) private var theme
    var fill: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(fill ?? theme.fill, in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct OutlineButton: ButtonStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(theme.text)
            .frame(maxWidth: .infinity, minHeight: 46)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.line, lineWidth: 1.5))
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct ScreenTitle: View {
    @Environment(\.theme) private var theme
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 32, weight: .bold)).foregroundStyle(theme.accent)
                .minimumScaleFactor(0.8).lineLimit(1)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
