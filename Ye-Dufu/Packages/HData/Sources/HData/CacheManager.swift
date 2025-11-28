import Foundation

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
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    public func getLocalURL(for remoteURL: URL) -> URL? {
        let fileName = remoteURL.lastPathComponent
        let localURL = cacheDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: localURL.path) {
            return localURL
        }
        return nil
    }
    
    public func cache(remoteURL: URL) {
        let fileName = remoteURL.lastPathComponent
        let localURL = cacheDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: localURL.path) {
            return
        }
        
        let task = URLSession.shared.downloadTask(with: remoteURL) { [weak self] tempURL, response, error in
            guard let self = self, let tempURL = tempURL, error == nil else {
                print("Download failed: \(String(describing: error))")
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
                print("Cached file at: \(localURL.path)")
            } catch {
                print("Failed to move file: \(error)")
            }
        }
        task.resume()
    }
}
