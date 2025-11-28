# HData

HData is a Swift package responsible for data management in the Ye-Dufu application. It primarily handles the downloading and caching of media resources.

## Features

- **CacheManager**: A singleton class that manages the caching of remote files.
  - Automatically creates a `Media` directory in the user's documents folder.
  - Checks if a file is already cached locally.
  - Downloads and caches files from remote URLs asynchronously.

## Usage

### Caching a File

Use `CacheManager.shared.cache(remoteURL:)` to download and cache a file from a remote URL.

```swift
import HData
import Foundation

if let url = URL(string: "https://example.com/audio.mp3") {
    CacheManager.shared.cache(remoteURL: url)
}
```

### Retrieving a Cached File

Use `CacheManager.shared.getLocalURL(for:)` to get the local file URL if it exists.

```swift
if let remoteURL = URL(string: "https://example.com/audio.mp3"),
   let localURL = CacheManager.shared.getLocalURL(for: remoteURL) {
    // Use localURL for playback or other operations
    print("File is available at: \(localURL.path)")
}
```
