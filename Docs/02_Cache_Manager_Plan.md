# Step 2: Cache Manager Implementation Plan

**Goal**: Stream audio by default but cache it locally for future offline playback.

## Class Design

*   **Name**: `CacheManager`
*   **Location**: `Packages/HMedia/Sources/HMedia/CacheManager.swift`
*   **Type**: Singleton (`shared` instance)

## Functionality

1.  **Directory Management**
    *   Use `FileManager.default`.
    *   Target directory: `Library/Caches` (appropriate for re-downloadable content).

2.  **File Naming Strategy**
    *   Use the `lastPathComponent` of the remote URL as the local filename.
    *   Example: `https://.../1-.mp3` -> `.../Caches/1-.mp3`.

3.  **Check Availability**
    *   **Method**: `getLocalURL(for remoteURL: URL) -> URL?`
    *   **Logic**: Check `FileManager.fileExists` at the expected local path. Return the local file URL if it exists, otherwise `nil`.

4.  **Background Downloading**
    *   **Method**: `cache(remoteURL: URL)`
    *   **Logic**:
        *   Check if file already exists (abort if true).
        *   Use `URLSession.shared.downloadTask(with: remoteURL)`.
        *   In the completion handler:
            *   Verify success.
            *   Move the temporary file to the permanent cache location using `FileManager.moveItem`.
            *   Handle potential errors (e.g., disk full, move failure).
