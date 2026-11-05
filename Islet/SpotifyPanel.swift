import SwiftUI

/// A compact player: artwork and title, a scrubber, and five controls.
struct SpotifyPanel: View {
    @Environment(IslandModel.self) private var model
    @Environment(Spotify.self) private var spotify

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: model.notchSize.height)
            if let track = spotify.track {
                PanelHeader(title: track.name, subtitle: "\(track.artist) · \(track.album)", close: model.close) {
                    Artwork(image: spotify.artwork, size: 44, radius: 10)
                }
                Scrubber(duration: track.duration)
                    .padding(.bottom, 8)
                HStack {
                    Button(action: spotify.toggleShuffle) { Image(systemName: "shuffle") }
                        .buttonStyle(IconStyle(foreground: spotify.shuffling ? Palette.spotify : Palette.secondary))
                        .accessibilityLabel("Shuffle")
                    Spacer()
                    Button(action: spotify.previous) { Image(systemName: "backward.fill") }
                        .buttonStyle(IconStyle(size: 40))
                        .accessibilityLabel("Previous")
                    Spacer()
                    Button(action: spotify.togglePlay) { Image(systemName: spotify.isPlaying ? "pause.fill" : "play.fill") }
                        .buttonStyle(IconStyle(size: 48, fill: .white, foreground: .black))
                        .accessibilityLabel(spotify.isPlaying ? "Pause" : "Play")
                    Spacer()
                    Button(action: spotify.next) { Image(systemName: "forward.fill") }
                        .buttonStyle(IconStyle(size: 40))
                        .accessibilityLabel("Next")
                    Spacer()
                    Button(action: spotify.toggleRepeat) { Image(systemName: "repeat") }
                        .buttonStyle(IconStyle(foreground: spotify.repeating ? Palette.spotify : Palette.secondary))
                        .accessibilityLabel("Repeat")
                }
            } else {
                PanelHeader(title: "Spotify", subtitle: "Nothing playing", close: model.close) { AppGlyph(app: .spotify, size: 44) }
                PanelPrompt(text: "Pick something in Spotify and it shows up here.", action: "Open Spotify", run: spotify.launch)
            }
        }
        .padding([.horizontal, .bottom], Metrics.panelPadding)
    }
}

/// Elapsed and remaining time; click or tap anywhere on the bar to jump there.
private struct Scrubber: View {
    @Environment(Spotify.self) private var spotify
    let duration: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let position = spotify.currentPosition
            let fraction = duration > 0 ? position / duration : 0
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.14))
                        Capsule().fill(.white).frame(width: geo.size.width * fraction)
                    }
                    .frame(height: 4)
                    .frame(maxHeight: .infinity)
                    .contentShape(.rect)
                    .onTapGesture { location in spotify.seek(to: location.x / geo.size.width) }
                }
                .frame(height: 16)
                HStack {
                    Text(Self.time(position))
                    Spacer()
                    Text("-" + Self.time(duration - position))
                }
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(Palette.secondary)
            }
        }
    }

    private static func time(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
