import Foundation
import HConstants
import Observation

public struct DownloadState: Sendable {
    public let progress: Double
    public let totalBytesWritten: Int64
    public let totalBytesExpectedToWrite: Int64
}

@Observable
final public class  CacheManager: NSObject, URLSessionDownloadDelegate {
    @MainActor public static let shared = CacheManager()
    
    public var downloadingURLs: Set<URL> = []
    public var downloadStates: [URL: DownloadState] = [:]
    public var cacheUpdateToken: UUID = UUID()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private var session: URLSession!
    private var backgroundCompletionHandler: (() -> Void)?
    
    private override init() {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsDirectory.appendingPathComponent("Media")
        super.init()
        
        let config = URLSessionConfiguration.background(withIdentifier: "com.yedufu.background.download")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        createCacheDirectory()
    }
    
    private func createCacheDirectory() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
                HLog.info("Created cache directory at \(cacheDirectory.path)", category: .data)
            } catch {
                HLog.error("Failed to create cache directory: \(error)", category: .data)
            }
        }
    }
    
    public func getLocalURL(for remoteURL: URL) -> URL? {
        let fileName = remoteURL.lastPathComponent
        let localURL = cacheDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: localURL.path) {
            HLog.debug("Cache hit for \(fileName)", category: .data)
            return localURL
        }
        HLog.debug("Cache miss for \(fileName)", category: .data)
        return nil
    }

    public func getLocalURL(for resource: AudioResource) -> URL? {
        return getLocalURL(for: resource.url)
    }
    
    public func isDownloaded(resource: AudioResource) -> Bool {
        return getLocalURL(for: resource) != nil
    }
    
    public func isDownloading(resource: AudioResource) -> Bool {
        return downloadingURLs.contains(resource.url)
    }
    
    public func getProgress(for resource: AudioResource) -> Double? {
        return downloadStates[resource.url]?.progress
    }
    
    public func getDownloadState(for resource: AudioResource) -> DownloadState? {
        return downloadStates[resource.url]
    }
    
    public func getFileSize(for resource: AudioResource) -> String? {
        guard let localURL = getLocalURL(for: resource) else { return nil }
        do {
            let attributes = try fileManager.attributesOfItem(atPath: localURL.path)
            if let size = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        } catch {
            HLog.error("Failed to get file size: \(error)", category: .data)
            return nil
        }
        return nil
    }
    
    public func cache(remoteURL: URL) {
        let fileName = remoteURL.lastPathComponent
        let localURL = cacheDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: localURL.path) {
            return
        }
        
        if downloadingURLs.contains(remoteURL) {
            return
        }
        
        downloadingURLs.insert(remoteURL)
        downloadStates[remoteURL] = DownloadState(progress: 0.0, totalBytesWritten: 0, totalBytesExpectedToWrite: 0)
        
        HLog.info("Starting download for \(fileName)", category: .network)
        let task = session.downloadTask(with: remoteURL)
        task.resume()
    }

    public func cache(resource: AudioResource) {
        cache(remoteURL: resource.url)
    }
    
    public func setBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
        self.backgroundCompletionHandler = handler
    }
    
    public func removeCache(for resource: AudioResource) {
        let fileName = resource.url.lastPathComponent
        let localURL = cacheDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: localURL.path) {
            do {
                try fileManager.removeItem(at: localURL)
                HLog.info("Removed cached file at: \(localURL.path)", category: .data)
                cacheUpdateToken = UUID()
            } catch {
                HLog.error("Failed to remove file: \(error)", category: .data)
            }
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    public nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let url = downloadTask.originalRequest?.url else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let state = DownloadState(progress: progress, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        
        Task { @MainActor in
            self.downloadStates[url] = state
        }
    }
    
    public nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let url = downloadTask.originalRequest?.url else { return }
        let fileName = url.lastPathComponent
        let localURL = cacheDirectory.appendingPathComponent(fileName)
        
        do {
            // Ensure the directory exists before moving (just in case)
            if !fileManager.fileExists(atPath: cacheDirectory.path) {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            // If file exists at destination (race condition), remove it first or handle error
            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }
            
            try fileManager.moveItem(at: location, to: localURL)
            HLog.info("Cached file at: \(localURL.path)", category: .data)
        } catch {
            HLog.error("Failed to move file: \(error)", category: .data)
        }
        
        Task { @MainActor in
            self.downloadingURLs.remove(url)
            self.downloadStates.removeValue(forKey: url)
            self.cacheUpdateToken = UUID()
        }
    }
    
    public nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let url = task.originalRequest?.url else { return }
        
        if let error = error {
            HLog.error("Download failed: \(error)", category: .network)
            Task { @MainActor in
                self.downloadingURLs.remove(url)
                self.downloadStates.removeValue(forKey: url)
            }
        }
    }
    
    public nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        HLog.info("Background download session finished all events", category: .network)
        Task { @MainActor in
            if let handler = self.backgroundCompletionHandler {
                self.backgroundCompletionHandler = nil
                handler()
                HLog.info("Background completion handler called", category: .network)
            }
        }
    }
}
