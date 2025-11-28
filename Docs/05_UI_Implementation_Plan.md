# Step 5: UI Implementation Plan

**Goal**: Provide a user interface to select chapters and control playback.

## View Controller Setup

*   **File**: `Ye-Dufu/Ye-Dufu/ViewController.swift`
*   **Components**:
    1.  **Chapter List**: `UITableView`
    2.  **Mini Player**: A custom `UIView` container at the bottom.

## UI Components Detail

1.  **Chapter List (TableView)**
    *   **DataSource**: `Chapter.all`.
    *   **Cell**: Standard `UITableViewCell` displaying `chapter.title`.
    *   **Selection**: On tap, call `AudioPlayerModel.shared.play(chapter:)`.

2.  **Mini Player**
    *   **Visibility**: Always visible (or hidden if no chapter has ever been played).
    *   **Subviews**:
        *   `UILabel`: Displays current chapter title.
        *   `UIButton`: Play/Pause toggle.
        *   `UIProgressView` or `UISlider`: Shows playback progress.
    *   **Layout**: Pinned to the bottom of the safe area.

## State Binding (Observation)

*   **Framework**: `Observation` (iOS 17+ / Swift 5.9+)
*   **Logic**:
    *   Use `withObservationTracking` inside `viewDidLoad` (or a setup method).
    *   **Track**: `player.currentChapter`, `player.isPlaying`, `player.currentTime`, `player.duration`.
    *   **OnChange**: Trigger a UI update function on the Main Actor.
    *   **Update Function**:
        *   Update Mini Player title label.
        *   Update Play/Pause button icon (`play.fill` vs `pause.fill`).
        *   Update Progress View (`currentTime / duration`).
