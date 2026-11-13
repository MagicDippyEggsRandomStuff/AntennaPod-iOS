import SwiftUI
import AntennaPodCore

struct MiniPlayerView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var player: PlaybackController

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(url: player.currentEpisode?.imageURL ?? podcastArtwork, size: 40, cornerRadius: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(player.displayTitle)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                Text(player.podcastTitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)

            Button {
                player.skipForward()
            } label: {
                Image(systemName: "goforward.fill")
                    .font(.body)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)
        )
        .overlay(alignment: .top) {
            ProgressView(value: player.progressFraction)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(x: 1, y: 0.6, anchor: .center)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .contentShape(Rectangle())
        .onTapGesture { model.showNowPlaying = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now playing: \(player.displayTitle)")
    }

    private var podcastArtwork: URL? {
        guard let episode = player.currentEpisode else { return nil }
        return model.library.podcast(id: episode.podcastID)?.imageURL
    }
}
