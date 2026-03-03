//
//  Utils.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/14/21.
//

import Foundation
import Dispatch
import SwiftUI
import SecurityFoundation

extension Date {
    func currentTimeMillis() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
    
    func moreRecentThan(_ date: Date) -> Bool {
        return self > date
    }
}

struct RuntimeError: Error {
    enum ErrorKind {
        case taskRun
        case noOutput
    }
    let message: String
    let kind: ErrorKind
}

class Utils {

    // MARK: - Cached Formatters
    // DateFormatter is expensive to create, so we cache static instances

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let monthShortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    /// Formats a date as a full date-time string
    ///
    /// - Parameter d: The date to format, or nil
    /// - Returns: Formatted string in "yyyy-MM-dd HH:mm:ss" format, or nil if date is nil
    static func dateToString(_ d: Date?) -> String? {
        guard let date = d else {
            return nil
        }
        return fullDateFormatter.string(from: date)
    }

    /// Formats a date as a relative or absolute string based on age
    ///
    /// For dates within the last 9 months, returns a human-readable relative string like
    /// "2 days ago" or "3 months ago". For older dates, returns "DD MMM YYYY" format.
    ///
    /// - Parameter d: The date to format, or nil
    /// - Returns: Formatted relative or absolute date string, or nil if date is nil
    static func relativeDateToString(_ d: Date?) -> String? {
        guard let date = d else {
            return nil
        }
        guard let check = Calendar.current.date(byAdding: .month, value: -9, to: Date()),
              date.moreRecentThan(check) else {
            return "\(Utils.getDayString(d)) "+"\(Utils.getMonthShort(d)) "+"\(Utils.getYear(d))"
        }
        return relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// Extracts the time component from a date
    ///
    /// - Parameter d: The date to extract time from, or nil
    /// - Returns: Time string in "HH:mm:ss" format, or empty string if date is nil
    static func getTime(_ d: Date?) -> String {
        guard let date = d else {
            return ""
        }
        return timeFormatter.string(from: date)
    }
    
    /// Extracts the day component from a date
    ///
    /// - Parameter d: The date to extract the day from, or nil
    /// - Returns: Day of month (1-31), or 0 if date is nil
    static func getDay(_ d: Date?) -> Int {
        if d == nil {
            return 0
        }
        let cal = Calendar.current
        return cal.component(.day, from: d!)
    }

    /// Extracts the month as a short abbreviated string
    ///
    /// - Parameter d: The date to extract the month from, or nil
    /// - Returns: Three-letter month abbreviation (e.g., "Jan", "Feb"), or "???" if date is nil
    static func getMonthShort(_ d: Date?) -> String {
        guard let date = d else {
            return "???"
        }
        return monthShortFormatter.string(from: date)
    }

    /// Formats the day component as a zero-padded two-digit string
    ///
    /// - Parameter d: The date to extract the day from, or nil
    /// - Returns: Two-digit day string (e.g., "01", "15", "31"), or "??" if date is nil
    static func getDayString(_ d: Date?) -> String {
        let day = getDay(d)
        var dayStr = ""
        if day == 0 {
            dayStr = "??"
        }

        if (day < 10) {
            dayStr = "0\(day)"
        } else {
            dayStr = "\(day)"
        }

        return dayStr
    }

    /// Extracts the year component from a date
    ///
    /// - Parameter d: The date to extract the year from, or nil
    /// - Returns: Four-digit year (e.g., 2021, 2024), or 0 if date is nil
    static func getYear(_ d: Date?) -> Int {
        guard let date = d else {
            return 0
        }
        return Calendar.current.component(.year, from: date)
    }
    
    /// Returns the color associated with a WiFi network's security type
    ///
    /// Color mapping:
    /// - WPA3: Green (most secure)
    /// - WPA2/WPA: Teal (secure)
    /// - WEP: Yellow (weak security)
    /// - Open: Red (no security)
    /// - Unknown: Gray
    ///
    /// - Parameter wifidata: The WiFi network data containing security information
    /// - Returns: SwiftUI Color representing the security level
    static func getSecurityColor(_ wifidata: WiFiData) -> Color {
        let stype = wifidata.securityType()
        var securityColor: Color = Color.gray
        switch stype {
        case .wpa3:
            securityColor = Color.green
        case .wpa2:
            securityColor = Color(NSColor.systemTeal)
        case .wpa:
            securityColor = Color(NSColor.systemTeal)
        case .wep:
            securityColor = Color.yellow
        case .open:
            securityColor = Color.red
        case .unknown:
            securityColor = Color.gray
        }
        return securityColor
    }

    /// Returns the color for a date box based on whether the date exists and the network's security
    ///
    /// - Parameters:
    ///   - wifidata: The WiFi network data
    ///   - d: The date to check, or nil
    /// - Returns: Gray if date is nil, otherwise the security color for the network
    static func getDateBoxColor(_ wifidata: WiFiData, _ d: Date?) -> Color {
        if d == nil {
            return Color.gray
        } else {
            return getSecurityColor(wifidata)
        }
    }
    
    /// Executes a command-line utility and returns its output
    ///
    /// This method runs external commands with timeout protection to prevent the app from hanging
    /// if a command becomes unresponsive. It captures both stdout and stderr.
    ///
    /// **Security:** Always validate and sanitize input parameters before passing to this method.
    /// Never pass user-controlled strings directly as the executable path. Use argument arrays
    /// instead of shell command strings to prevent injection attacks.
    ///
    /// **Timeout Behavior:** Commands that exceed the timeout period are automatically terminated.
    /// The default timeout is 30 seconds.
    ///
    /// - Parameters:
    ///   - executable: Full path to the executable (e.g., "/usr/sbin/networksetup")
    ///   - args: Array of command arguments (safely passed to Process, not through shell)
    ///   - env: Optional environment variables dictionary
    ///   - timeout: Maximum execution time in seconds (default: 30.0)
    /// - Returns: The command's stdout output as a string
    /// - Throws:
    ///   - `RuntimeError.taskRun`: If the process fails to start
    ///   - `RuntimeError.taskRun`: If the command times out
    ///   - `RuntimeError.noOutput`: If stdout is empty (stderr is included in error message)
    static func runCommand(_ executable: String, withArgs args: [String], withEnvironment env: [String:String]? = nil, timeout: TimeInterval = 30.0) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = args
        if let environment = env, !environment.isEmpty {
            task.environment = environment
        }
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
        } catch {
            throw RuntimeError(message: "\(error)", kind: .taskRun)
        }

        // Set up timeout handler
        var didTimeout = false
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler {
            if task.isRunning {
                task.terminate()
                didTimeout = true
            }
        }
        timer.resume()

        // Wait for process to complete
        task.waitUntilExit()
        timer.cancel()

        // Check if process timed out
        if didTimeout {
            throw RuntimeError(message: "Command timed out after \(timeout) seconds", kind: .taskRun)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let out = String(decoding: outputData, as: UTF8.self)
        let err = String(decoding: errorData, as: UTF8.self)

        if out.isEmpty {
            throw RuntimeError(message: "\(err)", kind: .noOutput)
        } else {
            return out
        }
    }
    
    
}

