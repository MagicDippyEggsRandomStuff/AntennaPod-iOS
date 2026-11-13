import SwiftUI
import AntennaPodCore

struct LibraryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            Group {
                if model.subscribedPodcasts.isEmpty {
                    EmptyStateView(
                        systemImage: "rectangle.stack.badge.plus",
                        title: "No subscriptions yet",
                        message: "Add a podcast by searching or pasting a feed URL.",
                        actionTitle: "Add podcast"
                    ) {
                        model.showingAddPodcast = true
                    }
                } else {
                    List {
                        if model.isRefreshing {
                            refreshHeader
                        }
                        ForEach(filteredPodcasts) { podcast in
                            NavigationLink(destination: PodcastDetailView(podcastID: podcast.id)) {
                                PodcastRow(podcast: podcast,
                                           episodeCount: model.library.episodes(for: podcast.id).count,
                                           unplayedCount: model.library.episodes(for: podcast.id).filter { !$0.isPlayed }.count)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await model.refreshAll() }
                }
            }
            .navigationTitle("Podcasts")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search subscriptions")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await model.refreshAll() }
                    } label: {
                        if model.isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(model.isRefreshing)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        model.showingAddPodcast = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var refreshHeader: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Refreshing \(model.refreshProgress.completed) of \(model.refreshProgress.total)")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var filteredPodcasts: [Podcast] {
        let all = model.subscribedPodcasts
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(query)
                || ($0.author?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
}

struct PodcastRow: View {
    let podcast: Podcast
    let episodeCount: Int
    let unplayedCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: podcast.imageURL, size: 60, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(podcast.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if let author = podcast.author, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text("\(episodeCount) episodes")
                    if unplayedCount > 0 {
                        Text("·")
                        Text("\(unplayedCount) new")
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
            if podcast.lastRefreshFailed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
        }
        .padding(.vertical, 3)
    }
}
