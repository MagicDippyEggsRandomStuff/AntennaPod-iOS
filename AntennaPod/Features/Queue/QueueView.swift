import SwiftUI
import AntennaPodCore

struct QueueView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingClearConfirmation = false

    private var queue: [Episode] { model.library.queueEpisodes }

    var body: some View {
        NavigationView {
            Group {
                if queue.isEmpty {
                    EmptyStateView(
                        systemImage: "list.bullet",
                        title: "Your queue is empty",
                        message: "Add episodes to your queue from the Podcasts or Inbox tabs.",
                        actionTitle: "Go to Inbox"
                    ) {
                        model.playFromQueueOrInbox()
                    }
                } else {
                    List {
                        Section(header: Text("Up next")) {
                            ForEach(queue) { episode in
                                EpisodeRow(episode: episode,
                                           podcast: model.podcast(for: episode),
                                           showPodcastTitle: true)
                            }
                            .onMove(perform: model.moveQueue)
                            .onDelete(perform: model.removeFromQueue)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Queue")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        model.togglePlayPause()
                    } label: {
                        Image(systemName: model.player.isPlaying ? "pause.fill" : "play.fill")
                    }
                    .disabled(queue.isEmpty && model.player.currentEpisode == nil)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        EditButton()
                        Button {
                            showingClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(queue.isEmpty)
                    }
                }
            }
            .confirmationDialog("Clear the queue?", isPresented: $showingClearConfirmation,
                                titleVisibility: .visible) {
                Button("Clear queue", role: .destructive) {
                    model.clearQueue()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
