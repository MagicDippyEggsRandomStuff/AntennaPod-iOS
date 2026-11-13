import SwiftUI
import AntennaPodCore

struct InboxView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filterFavorites = false

    private var episodes: [Episode] {
        filterFavorites ? model.library.favorites : model.library.inbox
    }

    var body: some View {
        NavigationView {
            Group {
                if episodes.isEmpty {
                    EmptyStateView(
                        systemImage: filterFavorites ? "heart" : "tray",
                        title: filterFavorites ? "No favorites yet" : "Inbox zero",
                        message: filterFavorites
                            ? "Mark episodes as favorites to find them here."
                            : "You have listened to everything. Add more podcasts to keep going."
                    )
                } else {
                    List {
                        ForEach(episodes) { episode in
                            EpisodeRow(episode: episode,
                                       podcast: model.podcast(for: episode),
                                       showPodcastTitle: true)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await model.refreshAll() }
                }
            }
            .navigationTitle(filterFavorites ? "Favorites" : "Inbox")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        filterFavorites.toggle()
                    } label: {
                        Image(systemName: filterFavorites ? "tray" : "heart")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            if let first = episodes.first { model.play(first) }
                        } label: {
                            Label("Play first episode", systemImage: "play.fill")
                        }
                        Button {
                            for episode in episodes {
                                model.enqueue(episode)
                            }
                        } label: {
                            Label("Add all to queue", systemImage: "text.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(episodes.isEmpty)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
