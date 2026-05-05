import Foundation

enum AppLogger {
    static func info(_ message: @autoclosure () -> String) {
        log("INFO", message)
    }
    
    static func debug(_ message: @autoclosure () -> String) {
        log("DEBUG", message)
    }
    
    static func error(_ message: @autoclosure () -> String) {
        log("ERROR", message)
    }
    
    private static func log(_ level: String, _ message: () -> String) {
        #if DEBUG
        print("[\(level)] \(message())")
        #endif
    }
}
