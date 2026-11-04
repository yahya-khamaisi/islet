import SwiftUI

/// Every size in Islet sits on an 8pt grid; the few values that aren't multiples of 8
/// (card padding, radii) are tuned to match macOS 27's own glass cards.
enum Metrics {
    /// Width of the open notch's content, not counting the top flares.
    static let openWidth: CGFloat = 680
    /// Padding between the notch's edge and its content, on every side.
    static let edge: CGFloat = 16
    /// Gap between cards.
    static let gap: CGFloat = 8
    static let cardPadding: CGFloat = 14
    static let cardRadius: CGFloat = 18
    /// All cards in a row share one height so the row reads as one block.
    static let cardHeight: CGFloat = 206
    static let openBottomRadius: CGFloat = 32
    static let closedBottomRadius: CGFloat = 12
    /// The small outward curve where the notch meets the menu bar.
    static let openFlare: CGFloat = 12
    static let closedFlare: CGFloat = 6
    /// Width each live-activity side adds to the closed notch.
    static let liveSlot: CGFloat = 64
}

enum Palette {
    static let spotify = Color(red: 0.12, green: 0.84, blue: 0.38)
    static let outlook = Color(red: 0.23, green: 0.59, blue: 0.87)
    static let claude = Color(red: 0.85, green: 0.47, blue: 0.34)
    static let attention = Color(red: 1, green: 0.62, blue: 0.04)
    static let done = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let action = Color(red: 0.04, green: 0.52, blue: 1)
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.55)
    static let fill = Color.white.opacity(0.06)
    static let hairline = Color.white.opacity(0.08)
}

/// The notch outline: concave flares at the top corners, rounded bottom corners.
struct NotchShape: Shape {
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

/// A glass card: one fill, one hairline, one radius, one padding.
struct Card<Content: View>: View {
    var outline: Color = Palette.hairline
    var padding: CGFloat = Metrics.cardPadding
    /// Fills the height it's given (cards in a row) or hugs its content (stacked cards).
    var fills = true
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: fills ? .infinity : nil, alignment: .topLeading)
            .background(Palette.fill, in: .rect(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(outline, lineWidth: outline == Palette.hairline ? 0.5 : 1)
            }
    }
}

/// The small icon-and-title line at the top of every card.
struct CardLabel: View {
    let symbol: String
    let tint: Color
    let title: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(title).foregroundStyle(Palette.secondary).lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.bottom, 10)
    }
}

/// Capsule button. One per card is `prominent`; the rest stay quiet.
struct PillStyle: ButtonStyle {
    var fill: Color = Color.white.opacity(0.1)
    var stretch = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .frame(maxWidth: stretch ? .infinity : nil)
            .background(fill.opacity(configuration.isPressed ? 0.6 : 1), in: .capsule)
            .foregroundStyle(.white)
            .contentShape(.capsule)
    }
}

/// Round icon-only button used in the header and the player.
struct IconStyle: ButtonStyle {
    var size: CGFloat = 28
    var filled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.48, weight: .medium))
            .frame(width: size, height: size)
            .background(filled ? Color.white.opacity(configuration.isPressed ? 0.16 : 0.06) : .clear, in: .circle)
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.6 : 0.85))
            .contentShape(.circle)
    }
}

struct Dot: View {
    let color: Color
    var pulsing = false
    @State private var dim = false
    var body: some View {
        Circle().fill(color).frame(width: 7, height: 7)
            .opacity(pulsing && dim ? 0.35 : 1)
            .onAppear {
                guard pulsing else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever()) { dim = true }
            }
    }
}

/// An empty or not-connected state: one line of text and one action.
struct CardPrompt: View {
    let text: String
    let action: String
    let run: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
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
