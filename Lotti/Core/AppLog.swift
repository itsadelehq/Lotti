// Core/AppLog.swift
import Foundation

/// Tiny, greppable logging helper for debugging the live dictation pipeline.
///
/// Every line is prefixed with `[Lotti]` so it is trivial to filter in
/// Console.app (search "[Lotti]") or in the Xcode console. Never log secret
/// values — log only "present"/"missing" for API keys.
///
/// In addition to stdout (invisible when the app is launched from Finder/Dock),
/// every line is appended to a persistent, timestamped log file at
/// `~/Library/Logs/Lotti/lotti.log`, so logs are readable regardless of how the
/// app was launched.
enum AppLog {
    /// Persistent log file location: ~/Library/Logs/Lotti/lotti.log
    private static let fileURL: URL = {
        let logsDir = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Lotti", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir,
                                                 withIntermediateDirectories: true)
        return logsDir.appendingPathComponent("lotti.log")
    }()

    private static let queue = DispatchQueue(label: "com.lotti.applog")

    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func log(_ message: String) {
        let line = "[Lotti] \(message)"
        print(line)
        appendToFile(line)
    }

    /// Call once at launch: rotates an oversized log and writes a launch marker.
    static func startup() {
        rotateIfNeeded()
        let stamp = DateFormatter.localizedString(from: Date(),
                                                  dateStyle: .medium, timeStyle: .medium)
        appendToFile("=== Lotti launched \(stamp) ===")
    }

    // MARK: - File output

    private static func appendToFile(_ line: String) {
        let stamped = "\(timestampFormatter.string(from: Date())) \(line)\n"
        queue.async {
            guard let data = stamped.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    /// Truncate the log if it has grown beyond ~1 MB so it can't grow unbounded.
    private static func rotateIfNeeded() {
        let maxBytes = 1_000_000
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int, size > maxBytes else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
