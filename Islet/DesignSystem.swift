import SwiftUI

/// Every size in Islet sits on a 4pt grid. Touch targets are at least 32pt; the island
/// itself never grows taller than the hardware notch until you open an app.
enum Metrics {
    /// One active app beside the notch. The whole slot is the click and touch target.
    static let slot: CGFloat = 36
    /// Breathing room between the outermost slot and the island's edge.
    static let slotInset: CGFloat = 4
    static let slotIcon: CGFloat = 20

    static let panelPadding: CGFloat = 18
    static let panelRadius: CGFloat = 30
    static let compactRadius: CGFloat = 12
    /// The small outward curve where the island meets the menu bar.
    static let panelFlare: CGFloat = 10
    static let compactFlare: CGFloat = 6

    static let cardPadding: CGFloat = 12
    static let cardRadius: CGFloat = 14
    static let rowHeight: CGFloat = 44
}

enum Palette {
    static let spotify = Color(red: 0.12, green: 0.84, blue: 0.38)
    static let outlook = Color(red: 0.23, green: 0.59, blue: 0.87)
    static let claude = Color(red: 0.85, green: 0.47, blue: 0.34)
    static let attention = Color(red: 1, green: 0.62, blue: 0.04)
    static let done = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let action = Color(red: 0.04, green: 0.52, blue: 1)
    static let secondary = Color.white.opacity(0.55)
    static let fill = Color.white.opacity(0.07)
    static let hairline = Color.white.opacity(0.08)
}

/// The island outline: concave flares at the top corners, rounded bottom corners.
struct IslandShape: Shape {
    var flare: CGFloat
    var bottom: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(flare, bottom) }
        set { flare = newValue.first; bottom = newValue.second }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + flare, y: r.minY + flare), control: CGPoint(x: r.minX + flare, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + flare, y: r.maxY - bottom))
        p.addQuadCurve(to: CGPoint(x: r.minX + flare + bottom, y: r.maxY), control: CGPoint(x: r.minX + flare, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - flare - bottom, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - flare, y: r.maxY - bottom), control: CGPoint(x: r.maxX - flare, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - flare, y: r.minY + flare))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.maxX - flare, y: r.minY))
        p.closeSubpath()
        return p
    }
}

/// A glass card inside a panel: one fill, one hairline, one radius, one padding.
struct Card<Content: View>: View {
    var outline: Color = Palette.hairline
    var tint: Color = Palette.fill
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: .rect(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(outline, lineWidth: outline == Palette.hairline ? 0.5 : 1)
            }
    }
}

/// Capsule button. At most one per panel is filled with a colour.
struct PillStyle: ButtonStyle {
    var fill: Color = Color.white.opacity(0.12)
    var stretch = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .frame(maxWidth: stretch ? .infinity : nil)
            .background(fill.opacity(configuration.isPressed ? 0.6 : 1), in: .capsule)
            .foregroundStyle(.white)
            .contentShape(.capsule)
    }
}

/// Round icon-only button.
struct IconStyle: ButtonStyle {
    var size: CGFloat = 32
    var fill: Color = .clear
    var foreground: Color = .white
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.46, weight: .semibold))
            .frame(width: size, height: size)
            .background(fill, in: .circle)
            .foregroundStyle(foreground.opacity(configuration.isPressed ? 0.5 : 1))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .contentShape(.circle)
    }
}

/// An app's glyph on a soft tile of its colour, used in slots and panel headers.
struct AppGlyph: View {
    let app: IslandModel.App
    var size: CGFloat = Metrics.slotIcon
    var body: some View {
        Image(systemName: app.symbol)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(app.tint)
            .frame(width: size, height: size)
            .background(app.tint.opacity(0.16), in: .rect(cornerRadius: size * 0.3, style: .continuous))
    }
}

/// Icon, title and subtitle at the top of every panel, with a close button.
struct PanelHeader<Icon: View>: View {
    let title: String
    let subtitle: String
    let close: () -> Void
    @ViewBuilder var icon: Icon

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: close) { Image(systemName: "xmark") }
                .buttonStyle(IconStyle(size: 26, fill: Palette.fill, foreground: Palette.secondary))
                .help("Close")
                .accessibilityLabel("Close")
        }
        .padding(.bottom, 14)
    }
}

struct Dot: View {
    let color: Color
    var pulsing = false
    @State private var dim = false
    var body: some View {
        Circle().fill(color).frame(width: 7, height: 7)
            .opacity(pulsing && dim ? 0.3 : 1)
            .onAppear {
                guard pulsing else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever()) { dim = true }
            }
    }
}

struct Artwork: View {
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat
    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Color(red: 0.23, green: 0.16, blue: 0.42), Color(red: 0.76, green: 0.25, blue: 0.05)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay { Image(systemName: "music.note").font(.system(size: size * 0.4)).foregroundStyle(.white.opacity(0.6)) }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: radius, style: .continuous))
    }
}

/// One line of text and one action, for empty and not-connected states.
struct PanelPrompt: View {
    let text: String
    let action: String
    let run: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action, action: run).buttonStyle(PillStyle(stretch: true))
        }
    }
}

extension Date {
    /// "now", "4m", "1h 5m".
    func elapsed(to end: Date = .now) -> String {
        let minutes = Int(end.timeIntervalSince(self) / 60)
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
