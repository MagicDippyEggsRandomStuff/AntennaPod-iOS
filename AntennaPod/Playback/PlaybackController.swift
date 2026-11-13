import AVFoundation
import Combine
import MediaPlayer
import UIKit
import AntennaPodCore

final class PlaybackController: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var currentEpisode: Episode?
    @Published private(set) var podcastTitle: String = ""
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var sleepTimerEnd: Date?
    @Published private(set) var isScrubbing: Bool = false

    var rate: Double = 1.0 {
        didSet {
            if isPlaying { player.playImmediately(atRate: Float(rate)) }
            updateNowPlaying()
        }
    }
    var skipForwardSeconds: Int = 30
    var skipBackwardSeconds: Int = 10

    var onProgress: ((String, TimeInterval, TimeInterval) -> Void)?
    var onFinished: ((String) -> Void)?
    var artworkURLProvider: ((Episode) -> URL?)?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var sleepTimer: Timer?
    private var artworkTask: Task<Void, Never>?
    private var nowPlayingArtwork: MPMediaItemArtwork?
    private var lastKnownDuration: TimeInterval = 0
    private var lastProgressReport: TimeInterval = 0

    override init() {
        super.init()
        player.automaticallyWaitsToMinimizeStalling = true
        configureAudioSession()
        addTimeObserver()
        registerRemoteCommands()
        observeNotifications()
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    var hasEpisode: Bool { currentEpisode != nil }

    var displayTitle: String { currentEpisode?.displayTitle ?? "Nothing playing" }

    var progressFraction: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentTime / duration))
    }

    func load(episode: Episode, podcastTitle: String, url: URL, startAt: TimeInterval, autoPlay: Bool = true) {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }

        let item = AVPlayerItem(url: url)
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            self?.handleItemFinished()
        }

        player.replaceCurrentItem(with: item)
        currentEpisode = episode
        self.podcastTitle = podcastTitle
        duration = episode.duration ?? 0
        lastKnownDuration = duration
        currentTime = max(0, startAt)
        nowPlayingArtwork = nil
        lastProgressReport = startAt

        if startAt > 1 {
            player.seek(to: CMTime(seconds: startAt, preferredTimescale: 600),
                        toleranceBefore: .zero, toleranceAfter: .zero)
        }

        updateNowPlaying()
        loadArtwork(for: episode)

        if autoPlay {
            play()
        }
    }

    func play() {
        guard player.currentItem != nil else { return }
        activateAudioSession()
        player.playImmediately(atRate: Float(rate))
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
        if let id = currentEpisode?.id {
            onProgress?(id, currentTime, duration)
        }
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func stop() {
        pause()
        cancelSleepTimer()
        player.replaceCurrentItem(with: nil)
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        currentEpisode = nil
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func seek(to time: TimeInterval) {
        guard player.currentItem != nil else { return }
        let upperBound = duration > 0 ? duration : time
        let clamped = min(max(0, time), upperBound)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
        updateNowPlaying()
    }

    func skip(by seconds: TimeInterval) {
        seek(to: currentTime + seconds)
    }

    func skipForward() {
        skip(by: TimeInterval(skipForwardSeconds))
    }

    func skipBackward() {
        skip(by: -TimeInterval(skipBackwardSeconds))
    }

    func beginScrubbing() {
        isScrubbing = true
    }

    func endScrubbing(at time: TimeInterval) {
        isScrubbing = false
        seek(to: time)
    }

    func startSleepTimer(minutes: Int) {
        cancelSleepTimer()
        let interval = TimeInterval(minutes) * 60
        sleepTimerEnd = Date().addingTimeInterval(interval)
        sleepTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.pause()
                self?.sleepTimerEnd = nil
            }
        }
    }

    func extendSleepTimer(minutes: Int) {
        guard let end = sleepTimerEnd else {
            startSleepTimer(minutes: minutes)
            return
        }
        let remaining = end.timeIntervalSinceNow + TimeInterval(minutes) * 60
        startSleepTimer(minutes: max(1, Int(remaining / 60)))
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerEnd = nil
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, !self.isScrubbing else { return }
            let seconds = time.seconds.isFinite ? time.seconds : 0
            self.currentTime = seconds

            if self.lastKnownDuration <= 0, let itemDuration = self.player.currentItem?.duration.seconds,
               itemDuration.isFinite, itemDuration > 0 {
                self.lastKnownDuration = itemDuration
                self.duration = itemDuration
            }

            DispatchQueue.main.async {
                MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seconds
            }

            if self.isPlaying,
               abs(seconds - self.lastProgressReport) >= 5,
               let episodeID = self.currentEpisode?.id {
                self.lastProgressReport = seconds
                self.onProgress?(episodeID, seconds, self.lastKnownDuration)
            }
        }
    }

    private func handleItemFinished() {
        isPlaying = false
        let finishedDuration = duration > 0 ? duration : currentTime
        currentTime = finishedDuration
        updateNowPlaying()
        if let id = currentEpisode?.id {
            onProgress?(id, finishedDuration, finishedDuration)
            onFinished?(id)
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
        } catch {
            NSLog("AntennaPod: could not configure audio session: \(error)")
        }
    }

    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            NSLog("AntennaPod: could not activate audio session: \(error)")
        }
    }

    private func updateNowPlaying() {
        guard let episode = currentEpisode else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: episode.displayTitle,
            MPMediaItemPropertyArtist: podcastTitle,
            MPMediaItemPropertyAlbumTitle: podcastTitle,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: rate
        ]
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = nowPlayingArtwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func loadArtwork(for episode: Episode) {
        guard let url = episode.imageURL ?? artworkURLProvider?(episode) else { return }
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            guard let result = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: result.0) else { return }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.nowPlayingArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.updateNowPlaying()
            }
        }
    }

    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.toggle() }
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: skipForwardSeconds)]
        center.skipForwardCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.skipForward() }
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipBackwardSeconds)]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.skipBackward() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            DispatchQueue.main.async { self?.seek(to: event.positionTime) }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.skipForward() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.skipBackward() }
            return .success
        }
    }

    func refreshPreferredIntervals() {
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: skipForwardSeconds)]
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipBackwardSeconds)]
    }

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification, object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            DispatchQueue.main.async { self.wasPlayingBeforeInterruption = self.isPlaying; self.pause() }
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            if options.contains(.shouldResume), wasPlayingBeforeInterruption {
                DispatchQueue.main.async { self.play() }
            }
        @unknown default:
            break
        }
    }

    private var wasPlayingBeforeInterruption = false

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
              reason == .oldDeviceUnavailable else { return }
        DispatchQueue.main.async { self.pause() }
    }
}
