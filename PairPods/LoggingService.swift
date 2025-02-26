//
//  LoggingService.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import Foundation
import os.log

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

enum AppError: Error {
    case operationError(String)
    case systemError(Error)
}

final class LoggingService {
    static let shared = LoggingService()
    private let osLog: OSLog

    private init() {
        osLog = OSLog(
            subsystem: Bundle.main.bundleIdentifier ?? "com.wozniakpawel.PairPods",
            category: "PairPods"
        )
    }

    func log(
        _ message: String,
        level: LogLevel,
        error: AppError? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        var logMessage = "[\(level.rawValue)] [\(fileName):\(line) \(function)] \(message)"

        if let error {
            logMessage += " Error: \(errorDescription(for: error))"
        }

        let type: OSLogType = switch level {
        case .debug: .debug
        case .info: .info
        case .warning: .default
        case .error: .error
        }

        os_log(type, log: osLog, "%{public}@", logMessage)
    }

    private func errorDescription(for error: AppError) -> String {
        switch error {
        case let .operationError(message):
            message
        case let .systemError(error):
            error.localizedDescription
        }
    }
}

func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    LoggingService.shared.log(message, level: .debug, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    LoggingService.shared.log(message, level: .info, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    LoggingService.shared.log(message, level: .warning, file: file, function: function, line: line)
}

func logError(_ message: String, error: AppError, file: String = #file, function: String = #function, line: Int = #line) {
    LoggingService.shared.log(message, level: .error, error: error, file: file, function: function, line: line)
}
