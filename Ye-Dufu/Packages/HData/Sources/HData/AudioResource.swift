import Foundation

public struct AudioResource: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}
