import Foundation
import HConstants

public class CacheManager {
    @MainActor public static let shared = CacheManager()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsDirectory.appendingPathComponent("Media")
        
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
    
    public func cache(remoteURL: URL) {
        let fileName = remoteURL.lastPathComponent
        let localURL = cacheDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: localURL.path) {
            return
        }
        
        HLog.info("Starting download for \(fileName)", category: .network)
        let task = URLSession.shared.downloadTask(with: remoteURL) { [weak self] tempURL, response, error in
            guard let self = self, let tempURL = tempURL, error == nil else {
                HLog.error("Download failed: \(String(describing: error))", category: .network)
                return
            }
            
            do {
                // Ensure the directory exists before moving (just in case)
                self.createCacheDirectory()
                
                // If file exists at destination (race condition), remove it first or handle error
                if self.fileManager.fileExists(atPath: localURL.path) {
                    try self.fileManager.removeItem(at: localURL)
                }
                
                try self.fileManager.moveItem(at: tempURL, to: localURL)
                HLog.info("Cached file at: \(localURL.path)", category: .data)
            } catch {
                HLog.error("Failed to move file: \(error)", category: .data)
            }
        }
        task.resume()
    }

    public func cache(resource: AudioResource) {
        cache(remoteURL: resource.url)
    }
}
