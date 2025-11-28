# Step 3: Audio Player Model Plan

**Goal**: Manage playback state, audio session, and remote commands using the new `@Observable` pattern.

## Class Design

*   **Name**: `AudioPlayerModel`
*   **Location**: `Packages/HMedia/Sources/HMedia/AudioPlayerModel.swift`
*   **Type**: `@Observable` class (Singleton `shared` instance recommended for global player state).

## State Properties

*   `currentChapter: Chapter?` (The currently playing or selected chapter)
*   `isPlaying: Bool` (Playback status)
*   `currentTime: TimeInterval` (Current playback position in seconds)
*   `duration: TimeInterval` (Total duration of the track)

## Core Logic

1.  **Playback Control**
    *   **Method**: `play(chapter: Chapter)`
        *   Check `CacheManager` for a local file.
        *   If local exists, play local URL.
        *   If not, play remote URL AND trigger `CacheManager.cache(remoteURL:)`.
        *   Initialize/Replace `AVPlayerItem` and `AVPlayer`.
        *   Start playback.
    *   **Method**: `togglePlayPause()`
        *   Toggle `player.rate` or call `play()`/`pause()`.
        *   Update `isPlaying`.
    *   **Method**: `seek(to time: TimeInterval)`
        *   Use `player.seek(to: CMTime...)`.

2.  **Time Observation**
    *   Use `player.addPeriodicTimeObserver(forInterval:queue:using:)` to update `currentTime` every ~0.5 seconds.
    *   Update `duration` from `player.currentItem?.duration`.

3.  **Remote Command Center (Lock Screen)**
    *   Import `MediaPlayer`.
    *   Configure `MPRemoteCommandCenter.shared()`.
    *   Handle `.playCommand`, `.pauseCommand`.
    *   Update `MPNowPlayingInfoCenter` with title, playback time, and duration.
