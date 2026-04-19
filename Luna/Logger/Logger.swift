//
//  Logging.swift
//  Sora
//
//  Created by seiike on 16/01/2025.
//

import Foundation

class Logger: @unchecked Sendable {
    static let shared = Logger()

    enum ExportError: Error {
        case encodingFailed
    }
    
    struct LogEntry {
        let message: String
        let type: String
        let timestamp: Date
    }
    
    private let queue = DispatchQueue(label: "me.cranci.sora.logger", attributes: .concurrent)
    private let fileQueue = DispatchQueue(label: "me.cranci.sora.logger.file")
    private var logs: [LogEntry] = []
    private let logFileURL: URL
    private let maxLogEntries = 1000
    private let maxLogFileBytes = 2_000_000
    
    private init() {
        // Use Documents folder for persistent logs (easier to access)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logFileURL = documentsURL.appendingPathComponent("player-logs.txt")
        ensureLogFileExists()
        logs = loadLogsFromDisk()
    }
    
    func log(_ message: String, type: String = "General") {
        let normalizedMessage = message.replacingOccurrences(of: "\n", with: " ")
        let entry = LogEntry(message: normalizedMessage, type: type, timestamp: Date())

        appendToDisk(entry)
        
        queue.async(flags: .barrier) {
            self.logs.append(entry)
            
            if self.logs.count > self.maxLogEntries {
                self.logs.removeFirst(self.logs.count - self.maxLogEntries)
            }
            
            self.debugLog(entry)
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("LoggerNotification"), object: nil,
                                                userInfo: [
                                                    "message": message,
                                                    "type": type,
                                                    "timestamp": entry.timestamp
                                                ]
                )
            }
        }
    }
    
    func getLogs() -> String {
        var result = ""
        queue.sync {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd-MM HH:mm:ss"
            result = logs.map { "[\(dateFormatter.string(from: $0.timestamp))] [\($0.type)] \($0.message)" }
                .joined(separator: "\n----\n")
        }
        return result
    }
    
    func getLogsAsync() async -> String {
        return await withCheckedContinuation { continuation in
            queue.async {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd-MM HH:mm:ss"
                let result = self.logs.map { "[\(dateFormatter.string(from: $0.timestamp))] [\($0.type)] \($0.message)" }
                    .joined(separator: "\n----\n")
                continuation.resume(returning: result)
            }
        }
    }
    
    func clearLogs() {
        queue.async(flags: .barrier) {
            self.logs.removeAll()
            self.fileQueue.sync {
                try? FileManager.default.removeItem(at: self.logFileURL)
                self.ensureLogFileExists()
            }
        }
    }
    
    func clearLogsAsync() async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.logs.removeAll()
                self.fileQueue.sync {
                    try? FileManager.default.removeItem(at: self.logFileURL)
                    self.ensureLogFileExists()
                }
                continuation.resume()
            }
        }
    }
    
    func exportLogsToTempFile() async throws -> URL {
        let logs = await getLogsAsync()
        let content = logs.isEmpty ? "No logs available." : logs
        guard let data = content.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "luna-logs-\(formatter.string(from: Date())).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
    
    private func debugLog(_ entry: LogEntry) {
#if DEBUG
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM HH:mm:ss"
        let formattedMessage = "[\(dateFormatter.string(from: entry.timestamp))] [\(entry.type)] \(entry.message)"
        print(formattedMessage)
#endif
    }

    private func ensureLogFileExists() {
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
    }

    private func appendToDisk(_ entry: LogEntry) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM HH:mm:ss"
        let line = "[\(dateFormatter.string(from: entry.timestamp))] [\(entry.type)] \(entry.message)\n"

        guard let data = line.data(using: .utf8) else { return }

        fileQueue.sync {
            rotateLogFileIfNeeded(incomingBytes: data.count)

            guard let handle = try? FileHandle(forWritingTo: logFileURL) else { return }
            defer { try? handle.close() }

            handle.seekToEndOfFile()
            handle.write(data)
            handle.synchronizeFile()
        }
    }

    private func rotateLogFileIfNeeded(incomingBytes: Int) {
        let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path)
        let currentSize = (attrs?[.size] as? NSNumber)?.intValue ?? 0
        if currentSize + incomingBytes <= maxLogFileBytes { return }

        try? FileManager.default.removeItem(at: logFileURL)
        ensureLogFileExists()
    }

    private func loadLogsFromDisk() -> [LogEntry] {
        var content = ""
        fileQueue.sync {
            content = (try? String(contentsOf: logFileURL, encoding: .utf8)) ?? ""
        }

        if content.isEmpty { return [] }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM HH:mm:ss"
        let pattern = #"\[([^\]]+)\] \[([^\]]+)\] (.+)"#
        let regex = try? NSRegularExpression(pattern: pattern)

        var parsed: [LogEntry] = []
        for line in content.split(separator: "\n") {
            let lineStr = String(line)
            guard let regex,
                  let match = regex.firstMatch(in: lineStr, range: NSRange(lineStr.startIndex..., in: lineStr)),
                  let timestampRange = Range(match.range(at: 1), in: lineStr),
                  let typeRange = Range(match.range(at: 2), in: lineStr),
                  let messageRange = Range(match.range(at: 3), in: lineStr),
                  let timestamp = dateFormatter.date(from: String(lineStr[timestampRange]))
            else {
                continue
            }

            parsed.append(
                LogEntry(
                    message: String(lineStr[messageRange]),
                    type: String(lineStr[typeRange]),
                    timestamp: timestamp
                )
            )
        }

        if parsed.count > maxLogEntries {
            return Array(parsed.suffix(maxLogEntries))
        }
        return parsed
    }
}
