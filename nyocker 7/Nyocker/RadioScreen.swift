import SafariServices
import SwiftUI

struct RadioScreen: View {
    @Environment(\.theme) private var theme
    @State private var index = 0
    @State private var listening: Release?
    @State private var spin = false
    private let radio = Content.shared.radio

    private var now: Release { radio[index] }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    ScreenTitle(title: "Rádió Nyócker")
                    Text("8.8 FM").font(.subheadline.weight(.bold)).foregroundStyle(theme.muted).fixedSize()
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        Vinyl(label: Color(css: now.color))
                            .frame(width: 92, height: 92)
                            .rotationEffect(.degrees(spin ? 360 : 0))
                            .animation(.linear(duration: 7).repeatForever(autoreverses: false), value: spin)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Pick \(index + 1) of \(radio.count)").font(.footnote.weight(.medium)).foregroundStyle(theme.accent)
                            Text(now.artist).font(.title3.weight(.bold)).foregroundStyle(theme.text)
                            Text(now.release).font(.subheadline).foregroundStyle(theme.muted)
                        }
                    }
                    Text(now.meta).font(.subheadline).foregroundStyle(theme.muted)
                    Button { listening = now } label: { Label("Listen", systemImage: "play.fill") }
                        .buttonStyle(PrimaryButton())
                    HStack(spacing: 10) {
                        Button("Previous") { step(-1) }.buttonStyle(OutlineButton())
                        Button("Next") { step(1) }.buttonStyle(OutlineButton())
                    }
                    Text("Plays on the artist's own Bandcamp page, so streams and sales stay with them.")
                        .font(.footnote).foregroundStyle(theme.muted)
                }
                .padding(16)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 18))

                Text("Playlist").font(.headline).foregroundStyle(theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                ForEach(Array(radio.enumerated()), id: \.element.id) { i, release in
                    Button { index = i } label: {
                        HStack(spacing: 12) {
                            Text(String(format: "%02d", i + 1)).font(.subheadline.weight(.bold))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(release.artist).font(.subheadline.weight(.bold))
                                Text(release.release).font(.footnote).multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .foregroundStyle(i == index ? Color.ink : theme.text)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(i == index ? theme.fill : theme.surface, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(16)
        }
        .background(theme.bg.ignoresSafeArea())
        .onAppear { spin = true }
        .sheet(item: $listening) { WebPage(url: $0.link).ignoresSafeArea() }
    }

    private func step(_ by: Int) {
        index = (index + by + radio.count) % radio.count
    }
}

struct Vinyl: View {
    let label: Color

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: 0x0A0918))
            ForEach([0.82, 0.68], id: \.self) { Circle().stroke(Color(hex: 0x2A2652), lineWidth: 1).scaleEffect($0) }
            Circle().fill(label).scaleEffect(0.36)
            Circle().fill(Color.ink).frame(width: 6, height: 6).offset(y: -12)
            Circle().fill(Color(hex: 0x0A0918)).scaleEffect(0.06)
        }
    }
}

/// Apple's in-app Safari, so releases and articles open on their own sites.
struct WebPage: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let page = SFSafariViewController(url: url)
        page.preferredBarTintColor = UIColor(red: 0.063, green: 0.055, blue: 0.149, alpha: 1)
        page.preferredControlTintColor = UIColor(red: 1, green: 0.824, blue: 0.247, alpha: 1)
        return page
    }

    func updateUIViewController(_ page: SFSafariViewController, context: Context) {}
}
