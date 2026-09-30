import Foundation

/// Append-only log file, so events that happen while the app is in the background survive for later reading.
enum Log {
    static let url = URL.documentsDirectory.appending(path: "spike-log.txt")
    private static let lock = NSLock()

    static func write(_ message: String) {
        let line = "\(Date.now.formatted(date: .omitted, time: .standard))  \(message)\n"
        print(line, terminator: "")
        lock.withLock {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? Data(line.utf8).write(to: url)
            }
        }
    }

    /// Newest line first.
    static func read() -> String {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return text.split(separator: "\n").reversed().joined(separator: "\n")
    }

    static func clear() {
        lock.withLock { try? FileManager.default.removeItem(at: url) }
    }
}
