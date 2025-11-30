## Plan: Sheet-based Player Control View

Present the player control as a sheet. Use system volume control and fixed-interval seek buttons.

### Steps
1. Create `PlayerControlViewController` in Ye-Dufu/Ye-Dufu with:
   - Play/pause button, progress slider, seek back/forward (e.g., ±15s), and system volume slider (using `MPVolumeView`).
2. Add tap gesture to `miniPlayerView` in `ViewController` to present `PlayerControlViewController` as a sheet (`.sheetPresentationController`).
3. Bind controls to `AudioPlayerModel` for playback, seeking, and progress.
4. Use observation to update UI in `PlayerControlViewController` as playback state changes.

### Further Considerations
1. Confirm seek interval (default: 15 seconds).
2. Ensure `MPVolumeView` is used for system volume.
3. Sheet should be dismissible and update in real time.
