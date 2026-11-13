import SwiftUI
import AntennaPodCore

struct EpisodeRow: View {
    @EnvironmentObject private var model: AppModel
    let episode: Episode
    var podcast: Podcast?
    var showPodcastTitle: Bool = false

    @State private var showingNotes = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ArtworkView(url: episode.imageURL ?? podcast?.imageURL, size: 58, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 4) {
                if showPodcastTitle, let podcast {
                    Text(podcast.displayTitle)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }

                Text(episode.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(episode.isPlayed ? .secondary : .primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    if let published = episode.publishedAt {
                        Text(Format.shortDate(published))
                    }
                    if let duration = episode.duration {
                        Text("·")
                        Text(DurationParser.formatted(duration))
                    }
                    if episode.isPlayed {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    if episode.isFavorite {
                        Image(systemName: "heart.fill").foregroundColor(.pink)
                    }
                    if model.isDownloaded(episode) {
                        Image(systemName: "arrow.down.circle.fill").foregroundColor(.green)
                    } else if model.isDownloading(episode) {
                        Image(systemName: "arrow.down.circle").foregroundColor(.orange)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if let progress = model.downloadProgress(for: episode) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                } else if episode.isInProgress, let duration = episode.duration, duration > 0 {
                    ProgressView(value: min(1, max(0, episode.playbackPosition / duration)))
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                }
            }

            Spacer(minLength: 0)

            Button {
                model.play(episode)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { model.play(episode) }
        .contextMenu {
            Button {
                model.play(episode)
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            Button {
                model.playNext(episode)
            } label: {
                Label("Play next", systemImage: "text.insert")
            }
            Button {
                model.enqueue(episode)
            } label: {
                Label("Add to queue", systemImage: "text.badge.plus")
            }

            Divider()

            if model.isDownloaded(episode) {
                Button {
                    model.deleteDownload(episode)
                } label: {
                    Label("Delete download", systemImage: "trash")
                }
            } else if model.isDownloading(episode) {
                Button {
                    model.cancelDownload(episode)
                } label: {
                    Label("Cancel download", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    model.download(episode)
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }

            Button {
                model.setPlayed(episode, played: !episode.isPlayed)
            } label: {
                Label(episode.isPlayed ? "Mark as unplayed" : "Mark as played",
                      systemImage: episode.isPlayed ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }

            Button {
                model.toggleFavorite(episode)
            } label: {
                Label(episode.isFavorite ? "Remove from favorites" : "Add to favorites",
                      systemImage: episode.isFavorite ? "heart.slash" : "heart")
            }

            if episode.summary != nil || episode.link != nil {
                Button {
                    showingNotes = true
                } label: {
                    Label("Show notes", systemImage: "doc.text")
                }
            }
        }
        .sheet(isPresented: $showingNotes) {
            EpisodeNotesView(episode: episode, podcast: podcast)
        }
    }
}

struct EpisodeNotesView: View {
    @Environment(\.dismiss) private var dismiss
    let episode: Episode
    let podcast: Podcast?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let podcast {
                        Text(podcast.displayTitle)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    Text(episode.displayTitle)
                        .font(.title3.weight(.bold))
                    HStack(spacing: 8) {
                        if let published = episode.publishedAt {
                            Text(Format.shortDate(published))
                        }
                        if let duration = episode.duration {
                            Text(DurationParser.formatted(duration))
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Divider()

                    if let summary = episode.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.body)
                            .textSelection(.enabled)
                    } else {
                        Text("No shownotes available for this episode.")
                            .foregroundColor(.secondary)
                    }

                    if let link = episode.link {
                        Link(destination: link) {
                            Label("Open episode page", systemImage: "safari")
                        }
                        .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Shownotes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
