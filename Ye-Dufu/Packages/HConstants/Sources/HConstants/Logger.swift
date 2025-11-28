import Foundation
import OSLog

public struct HLog {
    private static let logger = Logger(subsystem: "com.yedufu.hdata", category: "General")

    public static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, type: .debug, file: file, function: function, line: line)
    }

    public static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, type: .info, file: file, function: function, line: line)
    }

    public static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, type: .error, file: file, function: function, line: line)
    }

    private static func log(_ message: String, type: OSLogType, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        logger.log(level: type, "\(logMessage)")
    }
}
