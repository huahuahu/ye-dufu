## Plan: Add Download Manager Page

I will create a new "Download Manager" page to view download status and trigger downloads for audio files, and update the `CacheManager` to support observability.

### Steps
1.  **Update `CacheManager` in `HData`**:
    -   Mark `CacheManager` as `@Observable`.
    -   Add `downloadingURLs` property to track active downloads.
    -   Add `isDownloaded(resource:)` and `isDownloading(resource:)` helper methods.
    -   Update `cache(remoteURL:)` to manage the `downloadingURLs` state.

2.  **Create `DownloadManagerViewController`**:
    -   Create a new `UIViewController` subclass with a `UITableView`.
    -   Display the list of chapters (`Chapter.all`).
    -   Implement cells to show the title and a dynamic action button (Download / Downloading... / Downloaded).
    -   Use `withObservationTracking` to observe `CacheManager.shared` and update UI automatically.

3.  **Update `ViewController`**:
    -   Add a "Downloads" button (icon: `arrow.down.circle`) to the top-right of the screen.
    -   Implement the action to present `DownloadManagerViewController` modally.

### Further Considerations
1.  **Navigation**: I will present the new page modally since the current `ViewController` structure doesn't explicitly use a Navigation Controller.
2.  **Progress**: The current `URLSession` implementation doesn't easily support progress updates without a delegate. I will stick to a simple "Downloading..." state for now as requested.
3.  **Deletion**: The user didn't ask for deletion, so I will only implement "Download" and "View Status".
