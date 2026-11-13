import SwiftUI
import AntennaPodCore

struct PodcastDetailView: View {
    @EnvironmentObject private var model: AppModel
    let podcastID: String

    @State private var showingRename = false
    @State private var showingUnsubscribeConfirmation = false
    @State private var refreshing = false

    private var podcast: Podcast? { model.library.podcast(id: podcastID) }

    var body: some View {
        Group {
            if let podcast {
                content(for: podcast)
            } else {
                EmptyStateView(systemImage: "questionmark.circle",
                               title: "Podcast unavailable",
                               message: "This podcast is no longer in your library.")
            }
        }
        .navigationTitle(podcast?.displayTitle ?? "Podcast")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        Task { await refreshPodcast() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    Button {
                        showingRename = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button {
                        guard let podcast else { return }
                        model.setPodcastAutoDownload(podcastID: podcast.id, enabled: !podcast.autoDownload)
                    } label: {
                        Label(podcast?.autoDownload == true ? "Disable auto-download" : "Enable auto-download",
                              systemImage: "arrow.down.circle")
                    }
                    Button {
                        model.markAllPlayed(podcastID: podcastID)
                    } label: {
                        Label("Mark all as played", systemImage: "checkmark.circle")
                    }
                    Divider()
                    if let url = podcast?.feedURL {
                        Link(destination: url) {
                            Label("Open feed URL", systemImage: "safari")
                        }
                    }
                    if podcast?.isSubscribed == true {
                        Button(role: .destructive) {
                            showingUnsubscribeConfirmation = true
                        } label: {
                            Label("Unsubscribe", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingRename) {
            RenamePodcastSheet(initialTitle: podcast?.displayTitle ?? "", onSave: { newTitle in
                model.renamePodcast(podcastID: podcastID, title: newTitle)
            })
        }
        .confirmationDialog("Unsubscribe from this podcast?",
                            isPresented: $showingUnsubscribeConfirmation,
                            titleVisibility: .visible) {
            Button("Unsubscribe", role: .destructive) {
                model.unsubscribe(podcastID: podcastID)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Downloads for this podcast will be removed. Episode history is kept.")
        }
    }

    @ViewBuilder
    private func content(for podcast: Podcast) -> some View {
        List {
            Section {
                header(for: podcast)
            }

            if podcast.isSubscribed {
                Section {
                    Picker("Sort episodes", selection: sortBinding(for: podcast)) {
                        ForEach(EpisodeSortOrder.allCases, id: \.self) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                }
            }

            let episodes = model.library.episodes(for: podcast.id)
            Section(header: Text("\(episodes.count) episodes")) {
                if episodes.isEmpty {
                    Text("No episodes yet. Pull to refresh.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(episodes) { episode in
                        EpisodeRow(episode: episode, podcast: podcast)
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await refreshPodcast() }
    }

    private func header(for podcast: Podcast) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ArtworkView(url: podcast.imageURL, size: 92, cornerRadius: 12)
                VStack(alignment: .leading, spacing: 5) {
                    Text(podcast.displayTitle)
                        .font(.headline)
                    if let author = podcast.author, !author.isEmpty {
                        Text(author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    if let language = podcast.language {
                        Text(language.uppercased())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text("Updated \(Format.relative(podcast.lastRefreshedAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if let summary = podcast.summary, !summary.isEmpty {
                Text(summary)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(6)
            }

            HStack(spacing: 10) {
                if podcast.isSubscribed {
                    Button {
                        showingUnsubscribeConfirmation = true
                    } label: {
                        Label("Subscribed", systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                } else {
                    Button {
                        Task { try? await model.subscribe(feedURL: podcast.feedURL) }
                    } label: {
                        Label("Subscribe", systemImage: "plus.circle")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }

                if let website = podcast.websiteURL {
                    Link(destination: website) {
                        Label("Website", systemImage: "safari")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }

                if refreshing {
                    ProgressView()
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func sortBinding(for podcast: Podcast) -> Binding<EpisodeSortOrder> {
        Binding(
            get: { model.library.podcast(id: podcast.id)?.sortOrder ?? podcast.sortOrder },
            set: { model.setSortOrder(podcastID: podcast.id, order: $0) }
        )
    }

    private func refreshPodcast() async {
        refreshing = true
        await model.refresh(podcastID: podcastID)
        refreshing = false
    }
}

struct RenamePodcastSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    let onSave: (String) -> Void

    init(initialTitle: String, onSave: @escaping (String) -> Void) {
        _title = State(initialValue: initialTitle)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Podcast title")) {
                    TextField("Title", text: $title)
                }
                Section {
                    Text("Leave empty to use the title from the feed.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Rename podcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title)
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
