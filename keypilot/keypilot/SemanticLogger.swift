import Foundation

final class SemanticLogger {
    static let shared = SemanticLogger()

    let logFileURL: URL

    private let queue = DispatchQueue(label: "keypilot.logger", qos: .utility)
    private var fileHandle: FileHandle?

    private init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("keypilot", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        logFileURL = support.appendingPathComponent("semantic.log")

        // Open (or create) the file and keep a handle for efficient appends.
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        fileHandle?.seekToEndOfFile()
    }

    func log(_ message: String) {
        let line = "[\(iso8601())] \(message)\n"
        print("[keypilot] \(message)")
        queue.async { [weak self] in
            guard let self, let data = line.data(using: .utf8) else { return }
            self.fileHandle?.write(data)
        }
    }

    private func iso8601() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
