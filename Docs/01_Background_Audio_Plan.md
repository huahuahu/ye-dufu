# Step 1: Background Audio Configuration Plan

**Goal**: Enable the app to play audio while in the background or when the screen is locked.

## Actions

1.  **Info.plist Configuration**
    *   **File**: `Ye-Dufu/Ye-Dufu/Info.plist`
    *   **Action**: Add the `UIBackgroundModes` key.
    *   **Value**: Add `audio` (Audio, AirPlay, and Picture in Picture) to the array of background modes.

2.  **Audio Session Setup**
    *   **File**: `Ye-Dufu/Ye-Dufu/AppDelegate.swift`
    *   **Method**: `application(_:didFinishLaunchingWithOptions:)`
    *   **Logic**:
        *   Import `AVFoundation`.
        *   Get `AVAudioSession.sharedInstance()`.
        *   Set category to `.playback` with mode `.default`.
        *   Activate the session (`setActive(true)`).
        *   Add error handling (do-catch block) for the session setup.
