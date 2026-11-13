import SwiftUI
import AntennaPodCore

struct NowPlayingView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var player: PlaybackController
    @Environment(\.dismiss) private var dismiss

    @State private var sliderValue: Double = 0
    @State private var isEditing = false
    @State private var showingNotes = false

    private var episode: Episode? { player.currentEpisode }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 22) {
                    artwork
                    titles
                    scrubber
                    controls
                    secondaryControls
                    if let episode, episode.summary != nil || episode.link != nil {
                        Button {
                            showingNotes = true
                        } label: {
                            Label("Shownotes", systemImage: "doc.text")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }
            }
            .sheet(isPresented: $showingNotes) {
                if let episode {
                    EpisodeNotesView(episode: episode, podcast: model.podcast(for: episode))
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            sliderValue = player.currentTime
        }
        .onReceive(player.$currentTime) { time in
            if !isEditing { sliderValue = time }
        }
    }

    private var artwork: some View {
        ArtworkView(url: episode?.imageURL ?? podcastArtwork, size: 300, cornerRadius: 18)
            .frame(maxWidth: 320)
            .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
            .padding(.top, 8)
    }

    private var titles: some View {
        VStack(spacing: 6) {
            Text(episode?.displayTitle ?? "Nothing playing")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
            Text(player.podcastTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    private var scrubber: some View {
        VStack(spacing: 2) {
            Slider(value: $sliderValue,
                   in: 0...max(1, player.duration),
                   onEditingChanged: { editing in
                       isEditing = editing
                       if editing {
                           player.beginScrubbing()
                       } else {
                           player.endScrubbing(at: sliderValue)
                       }
                   })
                .accentColor(.orange)

            HStack {
                Text(DurationParser.formatted(isEditing ? sliderValue : player.currentTime))
                Spacer()
                Text(player.duration > 0 ? "-" + DurationParser.formatted(max(0, player.duration - (isEditing ? sliderValue : player.currentTime))) : "--:--")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .monospacedDigit()
        }
    }

    private var controls: some View {
        HStack(spacing: 38) {
            Button {
                player.skipBackward()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
            }

            Button {
                player.toggle()
            } label: {
                ZStack {
                    Circle().fill(Color.orange).frame(width: 74, height: 74)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.white)
                        .offset(x: player.isPlaying ? 0 : 2)
                }
            }

            Button {
                player.skipForward()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }

    private var secondaryControls: some View {
        HStack(spacing: 26) {
            Button {
                if let episode { model.toggleFavorite(episode) }
            } label: {
                Image(systemName: episode?.isFavorite == true ? "heart.fill" : "heart")
                    .foregroundColor(episode?.isFavorite == true ? .pink : .primary)
            }

            Menu {
                ForEach(AppSettings.speedOptions, id: \.self) { speed in
                    Button {
                        model.setPlaybackSpeed(speed)
                    } label: {
                        HStack {
                            Text(Format.speedLabel(speed))
                            if abs(model.library.settings.playbackSpeed - speed) < 0.001 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(Format.speedLabel(model.library.settings.playbackSpeed))
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 44)
            }

            Menu {
                Button("5 minutes") { player.startSleepTimer(minutes: 5) }
                Button("10 minutes") { player.startSleepTimer(minutes: 10) }
                Button("15 minutes") { player.startSleepTimer(minutes: 15) }
                Button("30 minutes") { player.startSleepTimer(minutes: 30) }
                Button("45 minutes") { player.startSleepTimer(minutes: 45) }
                Button("60 minutes") { player.startSleepTimer(minutes: 60) }
                if player.sleepTimerEnd != nil {
                    Divider()
                    Button("End sleep timer", role: .destructive) { player.cancelSleepTimer() }
                }
            } label: {
                Image(systemName: player.sleepTimerEnd == nil ? "moon" : "moon.fill")
                    .foregroundColor(player.sleepTimerEnd == nil ? .primary : .orange)
            }

            Button {
                if let episode { model.setPlayed(episode, played: !episode.isPlayed) }
            } label: {
                Image(systemName: episode?.isPlayed == true ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundColor(episode?.isPlayed == true ? .orange : .primary)
            }
        }
        .font(.title3)
        .padding(.top, 4)
    }

    private var podcastArtwork: URL? {
        guard let episode else { return nil }
        return model.library.podcast(id: episode.podcastID)?.imageURL
    }
}
