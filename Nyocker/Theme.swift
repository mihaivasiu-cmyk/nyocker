import Combine
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// Text on bright fills, whatever the time of day.
    static let ink = Color(hex: 0x16171A)
    static let mint = Color(hex: 0x8FA87A)
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
        case .dawn: return "First light"
        case .sunrise: return "Sunrise"
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .golden: return "Golden hour"
        case .sunset: return "Sunset"
        case .dusk: return "Dusk"
        case .night: return "Night"
        }
    }

    var symbol: String {
        switch self {
        case .dawn: return "sun.haze.fill"
        case .sunrise: return "sunrise.fill"
        case .morning, .midday: return "sun.max.fill"
        case .golden: return "sun.haze.fill"
        case .sunset: return "sunset.fill"
        case .dusk, .night: return "moon.stars.fill"
        }
    }

    /// The archive look: silver-print ink after dark, paper by day. The only warm colour
    /// is the ochre of the Rákóczi tér market hall roof (see pipeline/ARCHIVE.md).
    var palette: Palette {
        switch self {
        case .sunrise, .morning, .midday, .golden:
            return Palette(scheme: .light, bg: 0xE6E3DA, surface: 0xF2EFE6, raised: 0xD9D5C7, line: 0xB9B4AA, text: 0x16171A,
                           muted: 0x55595E, accent: 0x7A5A1F, link: 0x3F5A66, lore: 0xD9D5C7, fill: 0xCC9F53,
                           sky: [0xE6E3DA, 0xD9D5C7, 0xB9B4AA], skyInk: 0x16171A, body: 0xF2EFE6, bodyY: 0.38, moon: false,
                           stars: 0, windows: 0, far: 0x95999D, near: 0x55595E, ground: 0x3C3F44)
        case .dawn, .sunset, .dusk, .night:
            return Palette(scheme: .dark, bg: 0x16171A, surface: 0x1E1F23, raised: 0x2E3035, line: 0x3C3F44, text: 0xF2EFE6,
                           muted: 0x95999D, accent: 0xCC9F53, link: 0xA9C2CC, lore: 0x2A2220, fill: 0xCC9F53,
                           sky: [0x16171A, 0x1E1F23, 0x2E3035], skyInk: 0xF2EFE6, body: 0xE6E3DA, bodyY: 0.38, moon: true,
                           stars: 0.4, windows: 0.8, far: 0x2E3035, near: 0x1E1F23, ground: 0x16171A)
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
        case .lore: return "Lore"
        case .bar: return "Bars"
        case .club: return "Clubs"
        case .art: return "Art"
        case .eat: return "Eats"
        case .thrift: return "Second hand"
        case .local: return "Local"
        }
    }

    var tag: String {
        switch self {
        case .lore: return "LORE"
        case .bar: return "BAR"
        case .club: return "CLUB"
        case .art: return "ART SPACE"
        case .eat: return "EATS"
        case .thrift: return "SECOND HAND"
        case .local: return "LOCAL"
        }
    }

    /// Newer symbols fall back on iOS 15, where a missing one would draw a blank pin.
    var symbol: String {
        switch self {
        case .lore: return "exclamationmark"
        case .bar: return Self.best("wineglass.fill", or: "cup.and.saucer.fill")
        case .club: return "waveform"
        case .art: return "photo.artframe"
        case .eat: return "fork.knife"
        case .thrift: return Self.best("hanger", or: "tshirt.fill")
        case .local: return "house.fill"
        }
    }

    private static func best(_ symbol: String, or fallback: String) -> String {
        UIImage(systemName: symbol) == nil ? fallback : symbol
    }

    var hex: UInt32 {
        switch self {
        case .lore: return 0xB5483A
        case .bar: return 0xCC9F53
        case .club: return 0xC47A86
        case .art: return 0x7FA0AC
        case .eat: return 0xC27A45
        case .thrift: return 0x8FA87A
        case .local: return 0xD9D5C7
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
            .font(.system(size: 15, weight: .semibold))
            .textCase(.uppercase)
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
            .font(.system(size: 14, weight: .semibold))
            .textCase(.uppercase)
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
            Text(title.uppercased()).font(.system(size: 28, weight: .semibold)).tracking(3).foregroundStyle(theme.text)
                .minimumScaleFactor(0.7).lineLimit(1)
            if let subtitle {
                Text(subtitle).font(.system(.footnote, design: .monospaced)).foregroundStyle(theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
