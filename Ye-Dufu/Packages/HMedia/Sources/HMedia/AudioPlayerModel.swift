import Foundation
import Observation
import AVFoundation
import MediaPlayer
import UIKit
import HData
import HConstants

@Observable
@MainActor
public class AudioPlayerModel {
    public static let shared = AudioPlayerModel()

    public var currentChapter: Chapter?
    public var isPlaying: Bool = false
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 0
    public var volume: Float = 1.0 {
        didSet {
            player?.volume = volume
        }
    }

    private var player: AVPlayer?
    private var timeObserver: Any?
    private let skipInterval: TimeInterval = 15
    
    private let lastPlayedChapterTitleKey = "LastPlayedChapterTitle"
    private let lastPlayedTimeKey = "LastPlayedTime"

    private init() {
        setupRemoteCommands()
        restoreState()
        
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveState()
            }
        }
    }

    @MainActor
    public func play(chapter: Chapter, autoPlay: Bool = true) {
        HLog.info("Request to play chapter: \(chapter.title)", category: .media)
        // If it's the same chapter and we are paused, just resume
        if currentChapter?.title == chapter.title, let player = player {
            if autoPlay {
                activateAudioSession()
                player.play()
                isPlaying = true
                HLog.info("Resuming playback", category: .media)
            }
            return
        }

        currentChapter = chapter
        currentTime = 0
        
        // Check for local file
        let url: URL
        if let localURL = CacheManager.shared.getLocalURL(for: chapter.audioResource) {
            url = localURL
            HLog.info("Playing from local cache", category: .media)
        } else {
            url = chapter.audioResource.url
            HLog.info("Playing from remote URL", category: .media)
            // Trigger background caching
            Task {
                CacheManager.shared.cache(resource: chapter.audioResource)
            }
        }

        let playerItem = AVPlayerItem(url: url)
        
        // Clean up existing observer
        if let player = player, let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        player = AVPlayer(playerItem: playerItem)
        player?.volume = volume
        if autoPlay {
            activateAudioSession()
            player?.play()
            isPlaying = true
        } else {
            isPlaying = false
        }

        // Observe duration
        Task {
            if let duration = try? await playerItem.asset.load(.duration) {
                self.duration = CMTimeGetSeconds(duration)
                updateNowPlayingInfo()
            }
        }

        // Periodic time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentTime = CMTimeGetSeconds(time)
                self?.updateNowPlayingInfo()
            }
        }
        
        updateNowPlayingInfo()
        saveState()
    }

    public func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            deactivateAudioSession()
            saveState()
            HLog.info("Paused playback", category: .media)
        } else {
            activateAudioSession()
            player.play()
            HLog.info("Resumed playback", category: .media)
        }
        isPlaying.toggle()
        updateNowPlayingInfo()
    }

    public func seek(to time: TimeInterval) {
        guard let player = player else { return }
        HLog.info("Seeking to \(time)", category: .media)
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentTime = time
                self?.updateNowPlayingInfo()
            }
        }
    }

    private func activateAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            HLog.info("Audio session activated", category: .media)
        } catch {
            HLog.error("Failed to activate audio session: \(error)", category: .media)
        }
        #endif
    }
    
    private func deactivateAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            HLog.info("Audio session deactivated", category: .media)
        } catch {
            HLog.error("Failed to deactivate audio session: \(error)", category: .media)
        }
        #endif
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.isPlaying else {
                    HLog.info("Ignoring remote play command (already playing)", category: .media)
                    return
                }
                HLog.info("Remote play command received", category: .media)
                self.togglePlayPause()
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying else {
                    HLog.info("Ignoring remote pause command (already paused)", category: .media)
                    return
                }
                HLog.info("Remote pause command received", category: .media)
                self.togglePlayPause()
            }
            return .success
        }

        // Enable skip forward/backward commands
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: skipInterval)]
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipInterval)]

        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let newTime = min(self.currentTime + self.skipInterval, self.duration)
                self.seek(to: newTime)
                HLog.info("Skip forward \(self.skipInterval)s", category: .media)
            }
            return .success
        }

        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let newTime = max(self.currentTime - self.skipInterval, 0)
                self.seek(to: newTime)
                HLog.info("Skip backward \(self.skipInterval)s", category: .media)
            }
            return .success
        }

        // Allow scrubbing to a specific position (e.g., Control Center slider)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor [weak self] in
                self?.seek(to: posEvent.positionTime)
                HLog.info("Changed playback position to \(posEvent.positionTime)", category: .media)
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let chapter = currentChapter else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = chapter.title
        // Optional descriptive metadata to improve lock-screen and Control Center display
        // if let author = chapter.author {
        //     nowPlayingInfo[MPMediaItemPropertyArtist] = author
        // }
        // if let album = chapter.collectionTitle {
        //     nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        // }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        // Hint preferred skip interval to clients that support it
        nowPlayingInfo[MPNowPlayingInfoPropertyChapterCount] = 0
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0

        // Provide artwork if available to show a media card on lock screen
        // if let artworkImage = chapter.artworkImage {
        //     let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in artworkImage }
        //     nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        // }

        // Media type helps certain UIs decide rendering style
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func saveState() {
        guard let chapter = currentChapter else { return }
        HPersistence.shared.set(chapter.title, forKey: lastPlayedChapterTitleKey)
        HPersistence.shared.set(currentTime, forKey: lastPlayedTimeKey)
    }
    
    private func restoreState() {
        guard let title = HPersistence.shared.string(forKey: lastPlayedChapterTitleKey),
              let chapter = Chapter.all.first(where: { $0.title == title }) else { return }
        
        let time = HPersistence.shared.double(forKey: lastPlayedTimeKey)
        play(chapter: chapter, autoPlay: false)
        seek(to: time)
    }
}
