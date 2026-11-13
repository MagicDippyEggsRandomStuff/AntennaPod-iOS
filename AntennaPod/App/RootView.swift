import SwiftUI
import AntennaPodCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TabView {
            QueueView()
                .tabItem { Label("Queue", systemImage: "list.bullet") }

            LibraryView()
                .tabItem { Label("Podcasts", systemImage: "rectangle.stack") }

            InboxView()
                .tabItem { Label("Inbox", systemImage: "tray") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .accentColor(.orange)
        .overlay(alignment: .bottom) {
            if model.player.currentEpisode != nil {
                MiniPlayerView(player: model.player)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 54)
            }
        }
        .sheet(isPresented: $model.showNowPlaying) {
            NowPlayingView(player: model.player)
                .environmentObject(model)
        }
        .sheet(isPresented: $model.showingAddPodcast) {
            AddPodcastView()
                .environmentObject(model)
        }
        .alert(item: $model.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .preferredColorScheme(preferredScheme)
    }

    private var preferredScheme: ColorScheme? {
        switch model.library.settings.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
