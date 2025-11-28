import Foundation
import Observation
import AVFoundation
import MediaPlayer
import HData

@Observable
@MainActor
public class AudioPlayerModel {
    public static let shared = AudioPlayerModel()

    public var currentChapter: Chapter?
    public var isPlaying: Bool = false
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 0

    private var player: AVPlayer?
    private var timeObserver: Any?

    private init() {
        setupRemoteCommands()
        setupAudioSession()
    }

    @MainActor
    public func play(chapter: Chapter) {
        // If it's the same chapter and we are paused, just resume
        if currentChapter?.title == chapter.title, let player = player {
            player.play()
            isPlaying = true
            return
        }

        currentChapter = chapter
        
        // Check for local file
        let url: URL
        if let localURL = CacheManager.shared.getLocalURL(for: chapter.audioResource) {
            url = localURL
        } else {
            url = chapter.audioResource.url
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
        player?.play()
        isPlaying = true

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
    }

    public func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        updateNowPlayingInfo()
    }

    public func seek(to time: TimeInterval) {
        guard let player = player else { return }
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
        } catch {
            print("Failed to set up audio session: \(error)")
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
}
