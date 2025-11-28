// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import HData

public struct Chapter: Sendable {
    public let title: String
    public let audioResource: AudioResource

    public init(title: String, audioResource: AudioResource) {
        self.title = title
        self.audioResource = audioResource
    }
}

public extension Chapter {
    static let one = Chapter(title: "早期生活及诗作", audioResource: .one)
    static let two = Chapter(title: "在长安求仕时期生活及诗作", audioResource: .two)
    static let three = Chapter(title: "安史之乱将起时的一篇名作", audioResource: .three)
    static let four = Chapter(title: "身陷长安时的作品", audioResource: .four)
    static let six = Chapter(title: "长安收复后官拾遗时的作品", audioResource: .six)
    static let nine = Chapter(title: "杜甫的一组名诗", audioResource: .nine)

    static let all: [Chapter] = [.one, .two, .three, .four, .six, .nine]
}

public extension AudioResource {
    static let one = AudioResource(url: URL(string: "https://github.com/huahuahu/poemMedia/releases/download/media-v1/1-.mp3")!)
    static let two = AudioResource(url: URL(string: "https://github.com/huahuahu/poemMedia/releases/download/media-v1/2-.mp3")!)
    static let three = AudioResource(url: URL(string: "https://github.com/huahuahu/poemMedia/releases/download/media-v1/3-.mp3")!)
    static let four = AudioResource(url: URL(string: "https://github.com/huahuahu/poemMedia/releases/download/media-v1/4-.mp3")!)
    static let six = AudioResource(url: URL(string: "https://github.com/huahuahu/poemMedia/releases/download/media-v1/6-.mp3")!)
    static let nine = AudioResource(url: URL(string: "https://github.com/huahuahu/poemMedia/releases/download/media-v1/9-.mp3")!)
}