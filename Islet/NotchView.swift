import SwiftUI

/// The whole notch: black, flush with the hardware notch, growing into the open panel.
struct NotchView: View {
    @Environment(NotchModel.self) private var model

    var body: some View {
        let open = model.isOpen
        let flare = open ? Metrics.openFlare : Metrics.closedFlare
        Group {
            if open {
                OpenNotch()
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            } else {
                ClosedNotch().transition(.opacity)
            }
        }
        .padding(.horizontal, flare)
        .background(.black)
        .clipShape(NotchShape(flare: flare, bottom: open ? Metrics.openBottomRadius : Metrics.closedBottomRadius))
        .shadow(color: .black.opacity(open ? 0.55 : 0), radius: 24, y: 10)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { model.drawnSize = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: Closed

/// The closed notch, with Spotify on one side and your agents on the other while
/// either is live. Both sides always share one width so the hardware notch stays centred.
private struct ClosedNotch: View {
    @Environment(NotchModel.self) private var model
    @Environment(Spotify.self) private var spotify
    @Environment(AgentStore.self) private var agents
    @AppStorage(Defaults.widenForAgents) private var widenForAgents = true

    var body: some View {
        let playing = spotify.isPlaying && spotify.track != nil
        let request = widenForAgents ? agents.waiting.first : nil
        let running = agents.runningCount
        let live = playing || request != nil || running > 0
        let slot = request != nil ? 132 : live ? Metrics.liveSlot : 0

        HStack(spacing: 0) {
            HStack {
                if playing {
                    Artwork(image: spotify.artwork, size: 20, radius: 5)
                } else if live {
                    Image(systemName: "sparkle").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.claude)
                }
            }
            .frame(width: slot, alignment: .leading)
            .padding(.leading, live ? 10 : 0)

            Color.clear.frame(width: model.notchSize.width)

            HStack(spacing: 8) {
                if let request {
                    Dot(color: Palette.attention, pulsing: true)
                    Text("\(request.project) needs you")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.attention)
                        .lineLimit(1)
                } else {
                    if playing { Equalizer(color: Palette.spotify) }
                    if running > 0 {
                        HStack(spacing: 3) {
                            if playing { Image(systemName: "sparkle") }
                            Text(playing ? "\(running)" : "\(running) running")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.claude)
                        .lineLimit(1)
                    }
                }
            }
            .frame(width: slot, alignment: .trailing)
            .padding(.trailing, live ? 10 : 0)
        }
        .frame(height: model.notchSize.height)
        .contentShape(.rect)
        .onTapGesture { model.open(request != nil ? .tab(.agents) : nil) }
    }
}

/// Five bars that dance while music plays.
struct Equalizer: View {
    let color: Color
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 8)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<5) { i in
                    let h = 4 + 10 * abs(sin(t * (2.1 + Double(i) * 0.7) + Double(i)))
                    Capsule().fill(color).frame(width: 3, height: h)
                }
            }
            .frame(height: 14, alignment: .bottom)
            .animation(.easeInOut(duration: 0.12), value: t)
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

// MARK: Open

private struct OpenNotch: View {
    @Environment(NotchModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            // The hardware notch covers this band; nothing goes under it.
            Color.clear.frame(height: model.notchSize.height)
            Header()
                .padding(.horizontal, Metrics.edge)
                .padding(.top, 4)
                .padding(.bottom, 12)
            Group {
                switch model.page {
                case .tab(.home): HomeView()
                case .tab(.agents): AgentsView()
                case .tab(.calendar): CalendarView()
                case .settings: SettingsView()
                }
            }
            .transition(.opacity)
            .padding(.horizontal, Metrics.edge)
            .padding(.bottom, Metrics.edge)
        }
        .frame(width: Metrics.openWidth)
    }
}

private struct Header: View {
    @Environment(NotchModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 8) {
            if model.page == .settings {
                Button { model.show(.tab(.home)) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(IconStyle())
                    .help("Back")
                    .accessibilityLabel("Back")
                Text("Settings").font(.system(size: 14, weight: .semibold))
                Spacer()
            } else {
                TabBar()
                Spacer()
                Button { model.isPinned.toggle() } label: { Image(systemName: model.isPinned ? "pin.fill" : "pin") }
                    .buttonStyle(IconStyle())
                    .help(model.isPinned ? "Unpin" : "Keep open")
                    .accessibilityLabel(model.isPinned ? "Unpin" : "Keep open")
                Button { model.show(.settings) } label: { Image(systemName: "gearshape") }
                    .buttonStyle(IconStyle())
                    .help("Settings")
                    .accessibilityLabel("Settings")
            }
        }
        .frame(height: 32)
    }
}

private struct TabBar: View {
    @Environment(NotchModel.self) private var model
    @Environment(AgentStore.self) private var agents
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 2) {
            ForEach(NotchModel.Tab.allCases) { tab in
                let selected = model.page == .tab(tab)
                Button { model.show(.tab(tab)) } label: {
                    HStack(spacing: 6) {
                        Text(tab.title)
                        if tab == .agents, !agents.waiting.isEmpty {
                            Text("\(agents.waiting.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Palette.attention, in: .capsule)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(selected ? Palette.primary : Palette.secondary)
                    .padding(.horizontal, 14)
                    .frame(height: 26)
                    .background {
                        if selected {
                            Capsule().fill(.white.opacity(0.14)).matchedGeometryEffect(id: "tab", in: selection)
                        }
                    }
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Palette.fill, in: .capsule)
    }
}
