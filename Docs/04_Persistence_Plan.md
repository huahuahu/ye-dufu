# Step 4: Persistence Strategy Plan

**Goal**: Remember the user's last played chapter and position across app launches.

## Storage Mechanism

*   **Type**: `UserDefaults.standard`
*   **Keys**:
    *   `"LastPlayedChapterTitle"` (String)
    *   `"LastPlayedTime"` (Double)

## Integration with AudioPlayerModel

1.  **Saving State**
    *   **When**:
        *   When pausing playback.
        *   When switching chapters (save the *previous* chapter's progress if tracking per-chapter, or just the current state).
        *   (Optional) On app backgrounding (via `SceneDelegate` or notification observation).
    *   **What**: Save `currentChapter.title` and `currentTime`.

2.  **Restoring State**
    *   **When**: In `AudioPlayerModel.init()`.
    *   **Logic**:
        *   Read `LastPlayedChapterTitle`. Find the matching `Chapter` from `Chapter.all`.
        *   Read `LastPlayedTime`.
        *   Set `currentChapter` and `currentTime`.
        *   **Crucial**: Prepare the player with the file but **do not auto-play**. Use `player.seek(to: ...)` so the user sees the correct progress bar position immediately.
