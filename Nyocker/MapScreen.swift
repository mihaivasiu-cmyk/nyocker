import CoreLocation
import MapKit
import SwiftUI

struct MapScreen: View {
    @EnvironmentObject private var progress: Progress
    @EnvironmentObject private var eventFeed: EventStore
    @Environment(\.theme) private var theme
    @Binding var selected: Spot?
    @State private var filter: Category?
    @State private var showList = false
    @State private var focus = MapFocus(token: 0, spot: nil)
    @State private var trip: Trip?
    @State private var discovering: Spot?
    @State private var events: URL?
    @State private var spotEvents: Spot?
    private let spots = Content.shared.spots
    private let location = CLLocationManager()

    private var visible: [Spot] {
        filter.map { f in spots.filter { $0.category == f } } ?? spots
    }

    /// The venue's own programme page if it has one, else its dates from the feeds.
    private func openEvents(_ spot: Spot) {
        if let link = spot.eventsLink {
            events = link
        } else {
            spotEvents = spot
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            NyockerMap(spots: visible, found: progress.found, selected: $selected, focus: focus,
                       route: trip?.route, routeColor: UIColor(theme.accent),
                       style: theme.scheme == .dark ? .dark : .light)
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                header
                Spacer()
            }

            if let spot = selected {
                SpotCard(spot: spot, close: { selected = nil }, directions: { walk(to: spot) },
                         discover: spot.discoverPage == nil ? nil : { discovering = spot },
                         events: { openEvents(spot) })
                    .transition(.move(edge: .bottom))
            } else if let trip {
                RouteBar(trip: trip, end: { self.trip = nil }, open: { openInMaps(trip.spot) })
                    .transition(.move(edge: .bottom))
            } else {
                HStack {
                    Spacer()
                    Button { showList = true } label: {
                        Label("List view", systemImage: "list.bullet")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(Color.ink)
                            .padding(.horizontal, 16).frame(height: 46)
                            .background(theme.fill, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(14)
            }
        }
        .animation(.easeOut(duration: 0.22), value: selected?.id)
        .animation(.easeOut(duration: 0.22), value: trip)
        .onAppear { location.requestWhenInUseAuthorization() }
        .onChange(of: selected) { spot in
            guard let spot else { return }
            if let filter, filter != spot.category { self.filter = nil }
            focus = MapFocus(token: focus.token + 1, spot: spot)
        }
        .sheet(item: $events) { WebPage(url: $0).ignoresSafeArea() }
        .sheet(item: $spotEvents) { spot in
            SpotEventsSheet(spot: spot).environmentObject(eventFeed).environment(\.theme, theme)
        }
        .sheet(item: $discovering) { spot in
            if let page = spot.discoverPage {
                DiscoverScreen(page: page, spot: spot) {
                    discovering = nil
                    selected = nil
                    // Let the sheet finish closing before the map moves.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { walk(to: spot) }
                }
                .environmentObject(eventFeed).environment(\.theme, theme)
            }
        }
        .sheet(isPresented: $showList) {
            SpotList(spots: visible, title: filter?.title ?? "All spots") { spot in
                showList = false
                selected = spot
            }
            .environment(\.theme, theme)
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Nyócker").font(.system(size: 26, weight: .bold)).foregroundStyle(theme.accent)
                Spacer()
                Text("\(progress.found.count)/\(spots.count) found")
                    .font(.footnote.weight(.semibold)).foregroundStyle(Color.ink)
                    .padding(.horizontal, 11).padding(.vertical, 5)
                    .background(Color.mint, in: Capsule())
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", dot: theme.fill, on: filter == nil) { pick(nil) }
                    ForEach(Category.allCases) { c in
                        chip(c.title, dot: c.color, on: filter == c) { pick(c) }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 10)
            }
        }
        .background(theme.bg.opacity(0.95).ignoresSafeArea(edges: .top))
    }

    /// Asks Apple for a walking route from here and draws it on our own map.
    private func walk(to spot: Spot) {
        let status = location.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            if status == .notDetermined { location.requestWhenInUseAuthorization() }
            selected = nil
            trip = Trip(spot: spot, route: nil,
                        note: status == .notDetermined
                            ? "Allow location, then tap Directions again."
                            : "Turn on location for Nyócker in Settings to get walking directions here.")
            return
        }
        selected = nil
        trip = Trip(spot: spot, route: nil, note: nil)
        let request = MKDirections.Request()
        request.source = .forCurrentLocation()
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: spot.coordinate))
        request.transportType = .walking
        MKDirections(request: request).calculate { response, _ in
            DispatchQueue.main.async {
                guard trip?.spot.id == spot.id else { return }
                if let route = response?.routes.first {
                    trip = Trip(spot: spot, route: route, note: nil)
                } else {
                    trip = Trip(spot: spot, route: nil, note: "No walking route from where you are.")
                }
            }
        }
    }

    private func openInMaps(_ spot: Spot) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: spot.coordinate))
        item.name = spot.n
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    private func pick(_ category: Category?) {
        filter = category
        selected = nil
        focus = MapFocus(token: focus.token + 1, spot: nil)
    }

    private func chip(_ title: String, dot: Color, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle().fill(dot).frame(width: 8, height: 8)
                Text(title).font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 13).frame(height: 40)
            .background(on ? theme.text : theme.surface, in: Capsule())
            .foregroundStyle(on ? theme.bg : theme.text)
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// A walk to a spot: the route once Apple has worked it out, or why there isn't one.
struct Trip: Equatable {
    let spot: Spot
    let route: MKRoute?
    let note: String?

    static func == (a: Trip, b: Trip) -> Bool {
        a.spot.id == b.spot.id && a.route === b.route && a.note == b.note
    }
}

struct RouteBar: View {
    @Environment(\.theme) private var theme
    let trip: Trip
    let end: () -> Void
    let open: () -> Void

    private var summary: String {
        guard let route = trip.route else { return trip.note ?? "Finding a walking route…" }
        let minutes = max(1, Int((route.expectedTravelTime / 60).rounded()))
        let distance = MKDistanceFormatter()
        distance.unitStyle = .abbreviated
        return "\(minutes) min walk · \(distance.string(fromDistance: route.distance))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk").font(.system(size: 20, weight: .bold)).foregroundStyle(Color.ink)
                    .frame(width: 40, height: 40).background(theme.accent, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("To \(trip.spot.n)").font(.caption.weight(.bold)).foregroundStyle(theme.muted)
                    Text(summary).font(.headline).foregroundStyle(theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if trip.route == nil && trip.note == nil { ProgressView() }
            }
            HStack(spacing: 10) {
                Button("End", action: end).buttonStyle(OutlineButton())
                Button(action: open) { Label("Apple Maps", systemImage: "arrow.up.right") }
                    .buttonStyle(PrimaryButton())
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(theme.surface.clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.28), radius: 14, y: -4))
        .padding(.horizontal, 8).padding(.bottom, 8)
    }
}

/// A request to move the camera: to a spot, or back to the whole district.
struct MapFocus: Equatable {
    let token: Int
    let spot: Spot?
}

final class SpotAnnotation: NSObject, MKAnnotation {
    let spot: Spot
    var coordinate: CLLocationCoordinate2D { spot.coordinate }

    init(spot: Spot) {
        self.spot = spot
    }
}

/// Apple's map, by way of MKMapView because SwiftUI's own Map needs iOS 17.
struct NyockerMap: UIViewRepresentable {
    let spots: [Spot]
    let found: Set<String>
    @Binding var selected: Spot?
    let focus: MapFocus
    let route: MKRoute?
    let routeColor: UIColor
    let style: UIUserInterfaceStyle

    private static let district = MKCoordinateRegion(
        center: .init(latitude: 47.4895, longitude: 19.0765),
        span: .init(latitudeDelta: 0.026, longitudeDelta: 0.03))

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = true
        map.pointOfInterestFilter = .excludingAll
        map.layoutMargins = UIEdgeInsets(top: 118, left: 8, bottom: 8, right: 8)
        map.setRegion(Self.district, animated: false)

        let locate = MKUserTrackingButton(mapView: map)
        locate.backgroundColor = .secondarySystemBackground
        locate.layer.cornerRadius = 10
        locate.translatesAutoresizingMaskIntoConstraints = false
        map.addSubview(locate)
        NSLayoutConstraint.activate([
            locate.leadingAnchor.constraint(equalTo: map.leadingAnchor, constant: 14),
            locate.bottomAnchor.constraint(equalTo: map.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            locate.widthAnchor.constraint(equalToConstant: 44),
            locate.heightAnchor.constraint(equalToConstant: 44),
        ])
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        map.overrideUserInterfaceStyle = style
        coordinator.sync(map)

        if coordinator.route !== route {
            coordinator.route = route
            map.removeOverlays(map.overlays)
            if let route {
                map.addOverlay(route.polyline, level: .aboveRoads)
                map.setVisibleMapRect(route.polyline.boundingMapRect,
                                      edgePadding: UIEdgeInsets(top: 150, left: 50, bottom: 220, right: 50), animated: true)
            }
        }

        if coordinator.lastFocus != focus.token {
            coordinator.lastFocus = focus.token
            if let spot = focus.spot {
                let center = CLLocationCoordinate2D(latitude: spot.lat - 0.0034, longitude: spot.lon)
                map.setRegion(.init(center: center, span: .init(latitudeDelta: 0.009, longitudeDelta: 0.009)), animated: true)
            } else {
                map.setRegion(Self.district, animated: true)
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: NyockerMap
        var lastFocus = 0
        var route: MKRoute?
        private var shown: [String: SpotAnnotation] = [:]

        init(_ parent: NyockerMap) {
            self.parent = parent
        }

        func sync(_ map: MKMapView) {
            let wanted = Dictionary(uniqueKeysWithValues: parent.spots.map { ($0.id, $0) })
            let gone = shown.filter { wanted[$0.key] == nil }
            map.removeAnnotations(Array(gone.values))
            gone.keys.forEach { shown[$0] = nil }
            for (id, spot) in wanted where shown[id] == nil {
                let annotation = SpotAnnotation(spot: spot)
                shown[id] = annotation
                map.addAnnotation(annotation)
            }

            let current = (map.selectedAnnotations.first as? SpotAnnotation)?.spot.id
            if current != parent.selected?.id {
                map.selectedAnnotations.forEach { map.deselectAnnotation($0, animated: false) }
                if let id = parent.selected?.id, let annotation = shown[id] {
                    map.selectAnnotation(annotation, animated: false)
                }
            }
            for annotation in shown.values {
                if let view = map.view(for: annotation) { style(view, annotation) }
            }
        }

        private func style(_ view: MKAnnotationView, _ annotation: SpotAnnotation) {
            let spot = annotation.spot
            let big = parent.selected?.id == spot.id
            view.image = PinImage.make(category: spot.category, found: parent.found.contains(spot.id), big: big,
                                       outline: parent.style == .dark ? 0x16171A : 0xF2EFE6, icon: spot.icon)
            view.zPriority = big ? .max : .defaultUnselected
        }

        /// Dotted, like footsteps, in the accent of the hour.
        func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: line)
            renderer.strokeColor = parent.routeColor
            renderer.lineWidth = 7
            renderer.lineCap = .round
            renderer.lineDashPattern = [0, 13]
            return renderer
        }

        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? SpotAnnotation else { return nil }
            let view = map.dequeueReusableAnnotationView(withIdentifier: "spot")
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: "spot")
            view.annotation = annotation
            view.canShowCallout = false
            view.displayPriority = .required
            view.isAccessibilityElement = true
            view.accessibilityLabel = "\(annotation.spot.n), \(annotation.spot.category.tag)"
            style(view, annotation)
            return view
        }

        func mapView(_ map: MKMapView, didSelect view: MKAnnotationView) {
            guard let spot = (view.annotation as? SpotAnnotation)?.spot, parent.selected?.id != spot.id else { return }
            DispatchQueue.main.async { self.parent.selected = spot }
        }

        func mapView(_ map: MKMapView, didDeselect view: MKAnnotationView) {
            guard let spot = (view.annotation as? SpotAnnotation)?.spot, parent.selected?.id == spot.id else { return }
            DispatchQueue.main.async {
                if self.parent.selected?.id == spot.id, map.selectedAnnotations.isEmpty { self.parent.selected = nil }
            }
        }
    }
}

/// Map pins are drawn once per look, with a clear 44pt canvas so they stay easy to tap.
enum PinImage {
    private static var cache: [String: UIImage] = [:]

    static func make(category: Category, found: Bool, big: Bool, outline: UInt32, icon: String? = nil) -> UIImage {
        let key = "\(category.rawValue)-\(found)-\(big)-\(outline)-\(icon ?? "")"
        if let image = cache[key] { return image }
        // A venue's own art is the reward for finding it, so it only replaces the category pin once found.
        if found, let icon, let art = UIImage(named: icon) {
            let image = venue(art, category: category, big: big, outline: outline)
            cache[key] = image
            return image
        }
        let diameter: CGFloat = big ? 36 : 25
        let canvas = CGSize(width: 44, height: 44)
        let image = UIGraphicsImageRenderer(size: canvas).image { ctx in
            let circle = CGRect(x: (44 - diameter) / 2, y: (44 - diameter) / 2, width: diameter, height: diameter)
            UIColor(Color(hex: category.hex)).setFill()
            UIColor(Color(hex: outline)).setStroke()
            let path = UIBezierPath(ovalIn: circle.insetBy(dx: 0.75, dy: 0.75))
            path.lineWidth = 1.5
            path.fill()
            path.stroke()

            let config = UIImage.SymbolConfiguration(pointSize: big ? 16 : 11, weight: .bold)
            let ink = UIColor(category.ink)
            if let symbol = UIImage(systemName: found ? "checkmark" : category.symbol, withConfiguration: config)?
                .withTintColor(ink, renderingMode: .alwaysOriginal) {
                symbol.draw(at: CGPoint(x: (44 - symbol.size.width) / 2, y: (44 - symbol.size.height) / 2))
            }
        }
        cache[key] = image
        return image
    }

    /// A found venue with its own art gets a bigger badge: the art, ringed in its category colour, with a tick.
    private static func venue(_ art: UIImage, category: Category, big: Bool, outline: UInt32) -> UIImage {
        let diameter: CGFloat = big ? 44 : 34
        let side = max(44, diameter + 4)
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            let circle = CGRect(x: (side - diameter) / 2, y: (side - diameter) / 2, width: diameter, height: diameter)
            let ring = UIBezierPath(ovalIn: circle)
            UIColor(Color(hex: outline)).setFill()
            ring.fill()
            let inner = circle.insetBy(dx: 1.5, dy: 1.5)
            UIColor(Color(hex: category.hex)).setFill()
            UIBezierPath(ovalIn: inner).fill()
            let face = inner.insetBy(dx: 2.5, dy: 2.5)
            UIGraphicsGetCurrentContext()?.saveGState()
            UIBezierPath(ovalIn: face).addClip()
            art.draw(in: face)
            UIGraphicsGetCurrentContext()?.restoreGState()
            do {
                let badge = CGRect(x: circle.maxX - 15, y: circle.minY - 1, width: 16, height: 16)
                UIColor(Color.mint).setFill()
                UIBezierPath(ovalIn: badge).fill()
                let config = UIImage.SymbolConfiguration(pointSize: 9, weight: .black)
                if let tick = UIImage(systemName: "checkmark", withConfiguration: config)?
                    .withTintColor(UIColor(Color.ink), renderingMode: .alwaysOriginal) {
                    tick.draw(at: CGPoint(x: badge.midX - tick.size.width / 2, y: badge.midY - tick.size.height / 2))
                }
            }
        }
    }
}

struct SpotPin: View {
    let category: Category
    let found: Bool
    var icon: String?

    var body: some View {
        if found, let icon {
            Image(icon).resizable().scaledToFill().frame(width: 34, height: 34).clipShape(Circle())
                .overlay(Circle().stroke(category.color, lineWidth: 2.5))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "checkmark").font(.system(size: 8, weight: .black)).foregroundStyle(Color.ink)
                        .frame(width: 15, height: 15).background(Color.mint, in: Circle()).offset(x: 3, y: -3)
                }
        } else {
            symbol
        }
    }

    private var symbol: some View {
        ZStack {
            Circle().fill(category.color).frame(width: 30, height: 30)
            Image(systemName: found ? "checkmark" : category.symbol)
                .font(.system(size: 13, weight: .bold)).foregroundStyle(category.ink)
        }
    }
}

private struct HeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Sits over the map instead of in a system sheet, so it behaves the same on every iOS.
struct SpotCard: View {
    @EnvironmentObject private var progress: Progress
    @Environment(\.theme) private var theme
    let spot: Spot
    let close: () -> Void
    let directions: () -> Void
    var discover: (() -> Void)?
    var events: (() -> Void)?
    @State private var height: CGFloat = 0

    private var found: Bool { progress.found.contains(spot.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SpotPin(category: spot.category, found: found, icon: spot.icon)
                VStack(alignment: .leading, spacing: 1) {
                    Text(spot.tag).font(.system(.caption, design: .monospaced).weight(.medium)).foregroundStyle(theme.muted)
                    Text(spot.n).font(.title3.weight(.semibold)).foregroundStyle(theme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(theme.text)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Close")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let photo = ArchivePhoto.thenAndNow(for: spot.id)?.then, UIImage(named: photo.image) != nil {
                        HStack(alignment: .top, spacing: 12) {
                            Image(photo.image).resizable().scaledToFill()
                                .frame(width: 120, height: 84).clipped()
                                .overlay(alignment: .bottomLeading) {
                                    Text(photo.when).font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Color(hex: 0xF2EFE6))
                                        .padding(.horizontal, 5).padding(.vertical, 3)
                                        .background(Color(hex: 0x16171A).opacity(0.75), in: RoundedRectangle(cornerRadius: 3))
                                        .padding(5)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityLabel("\(photo.when): \(photo.story)")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(photo.story).font(.system(.subheadline, design: .serif)).foregroundStyle(theme.text)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(photo.credit).font(.system(size: 10, design: .monospaced)).foregroundStyle(theme.muted)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    Text(spot.a).font(.subheadline).foregroundStyle(theme.link)
                    Text(spot.d).font(.system(.subheadline, design: .serif)).foregroundStyle(theme.text)
                    if let src = spot.src {
                        Text("Source: \(src)").font(.footnote).foregroundStyle(theme.muted)
                    }
                    if spot.old == true {
                        Text("Older intel. Confirm before going.").font(.footnote).foregroundStyle(theme.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { Color.clear.preference(key: HeightKey.self, value: $0.size.height) })
            }
            .frame(height: min(max(height, 40), 240))
            .onPreferenceChange(HeightKey.self) { height = $0 }
            HStack(spacing: 10) {
                Button(found ? "Found it" : "Mark as found") {
                    progress.toggle(spot.id, in: \.found)
                }
                .buttonStyle(PrimaryButton(fill: found ? .mint : nil))
                Button(action: directions) { Label("Directions", systemImage: "figure.walk") }
                    .buttonStyle(OutlineButton())
            }
            if discover != nil || events != nil {
                HStack(spacing: 10) {
                    if let discover {
                        Button(action: discover) { Label("Discover", systemImage: "sparkles") }
                            .buttonStyle(page.map { BrandButton(fill: Color(css: $0.colors.brick), ink: Color(css: $0.colors.text ?? $0.colors.paper)) }
                                ?? BrandButton(fill: theme.raised, ink: theme.text))
                    }
                    if let events {
                        Button(action: events) { Label("Events", systemImage: "calendar") }
                            .buttonStyle(BrandButton(fill: theme.raised, ink: theme.text))
                    }
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background((spot.category == .lore ? theme.lore : theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.28), radius: 14, y: -4))
        .padding(.horizontal, 8).padding(.bottom, 8)
    }

    private var page: DiscoverPage? { spot.discoverPage }
}

struct SpotList: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let spots: [Spot]
    let title: String
    let open: (Spot) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.title3.weight(.bold)).foregroundStyle(theme.text)
                Spacer()
                Button("Done") { dismiss() }.font(.body.weight(.semibold)).foregroundStyle(theme.accent)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(spots) { spot in
                        Button { open(spot) } label: {
                            HStack(spacing: 12) {
                                SpotPin(category: spot.category, found: false, icon: spot.icon)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(spot.n).font(.body.weight(.semibold)).foregroundStyle(theme.text)
                                    Text(spot.a).font(.footnote).foregroundStyle(theme.muted)
                                }
                                .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
        }
        .background(theme.bg.ignoresSafeArea())
    }
}
