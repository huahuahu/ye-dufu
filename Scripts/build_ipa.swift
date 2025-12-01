#!/usr/bin/env swift

import Foundation

// MARK: - Configuration

struct Config {
    static let projectName = "Ye-Dufu"
    static let schemeName = "Ye-Dufu"
    // Path to the .xcodeproj relative to the repository root
    static let projectPath = "Ye-Dufu/Ye-Dufu.xcodeproj"
    
    static let buildDir = "Build"
    static let archivePath = "\(buildDir)/\(projectName).xcarchive"
    static let exportPath = "\(buildDir)/Output"
    static let exportOptionsPlistPath = "\(buildDir)/ExportOptions.plist"
    
    // Export method: development, ad-hoc, app-store, enterprise
    static let exportMethod = "release-testing"
        static let teamID = "F29WG8477A"

}

// MARK: - Shell Command Helper

func run(_ command: String, arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [command] + arguments
    
    // Pipe output to see it in real-time
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    
    print("🚀 Running: \(command) \(arguments.joined(separator: " "))")
    
    try process.run()
    process.waitUntilExit()
    
    if process.terminationStatus != 0 {
        throw NSError(domain: "ScriptError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Command failed: \(command)"])
    }
}

func runBash(_ command: String) throws {
    try run("bash", arguments: ["-c", command])
}

// MARK: - Steps

func clean() throws {
    print("\n🧹 Cleaning...")
    try runBash("rm -rf \(Config.buildDir)")
    try run("xcodebuild", arguments: [
        "clean",
        "-project", Config.projectPath,
        "-scheme", Config.schemeName,
        "-configuration", "Release"
    ])
}

func archive() throws {
    print("\n📦 Archiving...")
    try run("xcodebuild", arguments: [
        "archive",
        "-project", Config.projectPath,
        "-scheme", Config.schemeName,
        "-configuration", "Release",
        "-archivePath", Config.archivePath,
        "-sdk", "iphoneos",
        "-destination", "generic/platform=iOS"
    ])
}

func createExportOptions() throws {
    print("\n📝 Creating ExportOptions.plist...")
    let plistContent = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>method</key>
        <string>\(Config.exportMethod)</string>
        <key>compileBitcode</key>
        <false/>
        <key>thinning</key>
        <string>&lt;none&gt;</string>
        <key>stripSwiftSymbols</key>
        <true/>
        <key>teamID</key>
        <string>\(Config.teamID)</string> <!-- Leave empty to let Xcode pick automatically, or fill in if needed -->
    </dict>
    </plist>
    """
    
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: Config.buildDir) {
        try fileManager.createDirectory(atPath: Config.buildDir, withIntermediateDirectories: true)
    }
    
    try plistContent.write(toFile: Config.exportOptionsPlistPath, atomically: true, encoding: .utf8)
}

func export() throws {
    print("\n📤 Exporting IPA...")
    try run("xcodebuild", arguments: [
        "-exportArchive",
        "-archivePath", Config.archivePath,
        "-exportOptionsPlist", Config.exportOptionsPlistPath,
        "-exportPath", Config.exportPath
    ])
}

// MARK: - Main Execution

do {
    let fileManager = FileManager.default
    let currentPath = fileManager.currentDirectoryPath
    print("📂 Working directory: \(currentPath)")
    
    // Check if project exists
    if !fileManager.fileExists(atPath: Config.projectPath) {
        print("❌ Project file not found at: \(Config.projectPath)")
        print("Please run this script from the root of the repository.")
        exit(1)
    }

    try clean()
    try archive()
    try createExportOptions()
    try export()
    
    print("\n✅ Build Succeeded!")
    print("📱 IPA file is located at: \(Config.exportPath)/\(Config.projectName).ipa")
    
} catch {
    print("\n❌ Error: \(error.localizedDescription)")
    exit(1)
}
