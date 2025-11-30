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
    
    private let lastPlayedChapterTitleKey = "LastPlayedChapterTitle"
    private let lastPlayedTimeKey = "LastPlayedTime"

    private init() {
        setupRemoteCommands()
        setupAudioSession()
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
            saveState()
            HLog.info("Paused playback", category: .media)
        } else {
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

    private func setupAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            HLog.info("Audio session setup successful", category: .media)
        } catch {
            HLog.error("Failed to set up audio session: \(error)", category: .media)
        }
        #endif
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.togglePlayPause()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.togglePlayPause()
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
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

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
