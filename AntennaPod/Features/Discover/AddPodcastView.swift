import SwiftUI
import UniformTypeIdentifiers
import AntennaPodCore

struct AddPodcastView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode = 0
    @State private var query = ""
    @State private var urlText = ""
    @State private var results: [PodcastSearchResult] = []
    @State private var isSearching = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showingImporter = false
    @State private var importAlert: AppAlert?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Add method", selection: $mode) {
                    Text("Search").tag(0)
                    Text("Feed URL").tag(1)
                    Text("OPML").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }

                switch mode {
                case 0: searchPane
                case 1: urlPane
                default: importPane
                }
            }
            .navigationTitle("Add Podcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task(id: query) { await performSearch() }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.data],
                          allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .alert(item: $importAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message),
                      dismissButton: .default(Text("OK")) { dismiss() })
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var searchPane: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search podcasts", text: $query)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(10)
            .padding()

            List {
                if isSearching {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Searching…").foregroundColor(.secondary)
                    }
                }
                ForEach(results) { result in
                    Button {
                        subscribe(result)
                    } label: {
                        SearchResultRow(result: result)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
    }

    private var urlPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Paste the RSS or Atom feed address of a podcast.")
                .font(.footnote)
                .foregroundColor(.secondary)

            TextField("https://example.com/feed.xml", text: $urlText)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button {
                addFromURL()
            } label: {
                HStack {
                    if isWorking { ProgressView().padding(.trailing, 4) }
                    Text(isWorking ? "Adding…" : "Add podcast")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isWorking || urlText.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
        }
        .padding()
    }

    private var importPane: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.orange)
            Text("Import subscriptions")
                .font(.headline)
            Text("Choose an OPML file exported from AntennaPod or another podcast app.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingImporter = true
            } label: {
                HStack {
                    if isWorking { ProgressView().padding(.trailing, 4) }
                    Text(isWorking ? "Importing…" : "Choose file")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isWorking)
            Spacer()
        }
        .padding()
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        do {
            try await Task.sleep(nanoseconds: 350_000_000)
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        do {
            let found = try await model.searchClient.search(term: trimmed)
            results = found
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    private func subscribe(_ result: PodcastSearchResult) {
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await model.subscribe(searchResult: result)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }

    private func addFromURL() {
        guard let url = model.normalizedFeedURL(from: urlText) else {
            errorMessage = "That does not look like a valid feed URL."
            return
        }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await model.subscribe(feedURL: url)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                errorMessage = "The selected file could not be read."
                return
            }
            isWorking = true
            Task {
                let message = await model.importOPML(data: data)
                isWorking = false
                importAlert = AppAlert(title: "Import finished", message: message)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

struct SearchResultRow: View {
    let result: PodcastSearchResult

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: result.artworkURL, size: 54, cornerRadius: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if let author = result.author {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                if let genre = result.genre {
                    Text(genre)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "plus.circle")
                .foregroundColor(.orange)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
