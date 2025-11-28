import Foundation
import Synchronization

public final class HPersistence: Sendable {
    public static let shared = HPersistence()
    
    nonisolated(unsafe) private let defaults = UserDefaults.standard
    private let lock = Mutex(())

    private init() {}

    public func string(forKey key: String) -> String? {
        lock.withLock { _ in defaults.string(forKey: key) }
    }

    public func double(forKey key: String) -> Double {
        lock.withLock { _ in defaults.double(forKey: key) }
    }

    public func set(_ value: Any?, forKey key: String) {
        lock.withLock { _ in defaults.set(value, forKey: key) }
    }
}
