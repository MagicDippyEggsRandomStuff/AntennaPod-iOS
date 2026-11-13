import SwiftUI
import UniformTypeIdentifiers
import AntennaPodCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    @State private var showingImporter = false
    @State private var shareItem: ShareItem?
    @State private var showingDeleteDownloads = false
    @State private var importAlert: AppAlert?

    private var settings: AppSettings { model.library.settings }

    var body: some View {
        NavigationView {
            Form {
                playbackSection
                downloadsSection
                subscriptionsSection
                appearanceSection
                aboutSection
            }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.data],
                          allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .sheet(item: $shareItem) { item in
                ActivityView(items: [item.url])
            }
            .alert(item: $importAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message),
                      dismissButton: .default(Text("OK")))
            }
            .confirmationDialog("Delete all downloads?",
                                isPresented: $showingDeleteDownloads,
                                titleVisibility: .visible) {
                Button("Delete all downloads", role: .destructive) {
                    model.deleteAllDownloads()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes downloaded audio files but keeps your subscriptions and playback positions.")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var playbackSection: some View {
        Section(header: Text("Playback")) {
            Menu {
                ForEach(AppSettings.speedOptions, id: \.self) { speed in
                    Button {
                        model.setPlaybackSpeed(speed)
                    } label: {
                        HStack {
                            Text(Format.speedLabel(speed))
                            if abs(settings.playbackSpeed - speed) < 0.001 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Playback speed")
                    Spacer()
                    Text(Format.speedLabel(settings.playbackSpeed))
                        .foregroundColor(.secondary)
                }
            }

            Picker("Skip forward", selection: Binding(
                get: { settings.skipForwardSeconds },
                set: { newValue in
                    model.setSkipIntervals(forward: newValue, backward: settings.skipBackwardSeconds)
                }
            )) {
                ForEach([5, 10, 15, 20, 30, 45, 60, 90], id: \.self) { seconds in
                    Text(Format.minutes(seconds)).tag(seconds)
                }
            }

            Picker("Skip backward", selection: Binding(
                get: { settings.skipBackwardSeconds },
                set: { newValue in
                    model.setSkipIntervals(forward: settings.skipForwardSeconds, backward: newValue)
                }
            )) {
                ForEach([5, 10, 15, 20, 30, 45, 60], id: \.self) { seconds in
                    Text(Format.minutes(seconds)).tag(seconds)
                }
            }

            Toggle("Continuous playback", isOn: Binding(
                get: { settings.continuousPlayback },
                set: { newValue in model.updateSettings { $0.continuousPlayback = newValue } }
            ))
        }
    }

    private var downloadsSection: some View {
        Section(header: Text("Downloads"),
                footer: Text("\(model.downloadCount) downloaded episodes · \(model.downloadedBytesDescription)")) {
            Toggle("Auto-download new episodes", isOn: Binding(
                get: { settings.autoDownloadNewEpisodes },
                set: { newValue in model.updateSettings { $0.autoDownloadNewEpisodes = newValue } }
            ))

            Stepper("Episodes per podcast: \(settings.autoDownloadLimitPerPodcast)",
                    value: Binding(
                        get: { settings.autoDownloadLimitPerPodcast },
                        set: { newValue in model.updateSettings { $0.autoDownloadLimitPerPodcast = max(1, newValue) } }
                    ),
                    in: 1...10)

            Toggle("Stream only on Wi-Fi", isOn: Binding(
                get: { settings.streamOnlyOnWiFi },
                set: { newValue in model.updateSettings { $0.streamOnlyOnWiFi = newValue } }
            ))

            Button(role: .destructive) {
                showingDeleteDownloads = true
            } label: {
                Text("Delete all downloads")
            }
            .disabled(model.downloadCount == 0)
        }
    }

    private var subscriptionsSection: some View {
        Section(header: Text("Subscriptions"),
                footer: Text("Last refreshed \(Format.relative(settings.lastRefreshAt))")) {
            Button {
                Task { await model.refreshAll() }
            } label: {
                HStack {
                    Text("Refresh all podcasts")
                    Spacer()
                    if model.isRefreshing { ProgressView() }
                }
            }
            .disabled(model.subscribedPodcasts.isEmpty || model.isRefreshing)

            Picker("Refresh every", selection: Binding(
                get: { settings.refreshIntervalHours },
                set: { newValue in model.updateSettings { $0.refreshIntervalHours = newValue } }
            )) {
                ForEach([1, 3, 6, 12, 24], id: \.self) { hours in
                    Text("\(hours) hour\(hours == 1 ? "" : "s")").tag(hours)
                }
            }

            Button {
                exportOPML()
            } label: {
                Label("Export subscriptions (OPML)", systemImage: "square.and.arrow.up")
            }
            .disabled(model.subscribedPodcasts.isEmpty)

            Button {
                showingImporter = true
            } label: {
                Label("Import subscriptions (OPML)", systemImage: "square.and.arrow.down")
            }

            Button {
                model.showingAddPodcast = true
            } label: {
                Label("Add a podcast", systemImage: "plus")
            }
        }
    }

    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            Picker("Theme", selection: Binding(
                get: { settings.theme },
                set: { newValue in model.updateSettings { $0.theme = newValue } }
            )) {
                Text("System").tag(AppTheme.system)
                Text("Light").tag(AppTheme.light)
                Text("Dark").tag(AppTheme.dark)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    private var aboutSection: some View {
        Section(header: Text("About")) {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.secondary)
            }
            Link(destination: URL(string: "https://antennapod.org")!) {
                Label("AntennaPod website", systemImage: "safari")
            }
            Link(destination: URL(string: "https://github.com/MagicDippyEggsRandomStuff/AntennaPod-iOS")!) {
                Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Link(destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!) {
                Label("License (GPL-3.0)", systemImage: "doc.text")
            }
            Text("This is an independent iOS port of AntennaPod, which is developed by the AntennaPod community. It is not affiliated with the Android app's maintainers.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func exportOPML() {
        let xml = model.exportOPML()
        let name = "antennapod-subscriptions.opml"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try xml.write(to: url, atomically: true, encoding: .utf8)
            shareItem = ShareItem(url: url)
        } catch {
            importAlert = AppAlert(title: "Export failed", message: error.localizedDescription)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                importAlert = AppAlert(title: "Import failed", message: "The selected file could not be read.")
                return
            }
            Task {
                let message = await model.importOPML(data: data)
                importAlert = AppAlert(title: "Import finished", message: message)
            }
        case .failure(let error):
            importAlert = AppAlert(title: "Import failed", message: error.localizedDescription)
        }
    }
}
