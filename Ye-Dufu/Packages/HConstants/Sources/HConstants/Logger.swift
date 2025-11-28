import Foundation
import OSLog

public struct HLog {
    public enum Category: String {
        case general = "General"
        case ui = "UI"
        case network = "Network"
        case data = "Data"
        case media = "Media"
    }

    private static let subsystem = "com.yedufu"

    public static func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, type: .debug, category: category, file: file, function: function, line: line)
    }

    public static func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, type: .info, category: category, file: file, function: function, line: line)
    }

    public static func error(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, type: .error, category: category, file: file, function: function, line: line)
    }

    private static func log(_ message: String, type: OSLogType, category: Category, file: String, function: String, line: Int) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        logger.log(level: type, "\(logMessage)")
    }
}
