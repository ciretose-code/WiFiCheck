//
//  Utils.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/14/21.
//

import Foundation
import Dispatch
import os.log
import SwiftUI

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

struct UpdateRelease: Decodable {
    let tagName: String
    let htmlURL: URL

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }

    var displayVersion: String {
        UpdateChecker.displayVersion(tagName)
    }
}

enum UpdateCheckResult {
    case upToDate(currentTag: String)
    case updateAvailable(currentTag: String, release: UpdateRelease)
}

enum UpdateCheckError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case unexpectedStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "The update check URL is invalid."
        case .invalidResponse:
            return "GitHub returned an invalid response."
        case .unexpectedStatus(let statusCode):
            return "GitHub returned HTTP \(statusCode)."
        }
    }
}

enum UpdateChecker {
    private static let logger = Logger(subsystem: "com.ciretose.wificheck", category: "UpdateChecker")

    static func currentVersionTag() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "v\(version).\(build)"
    }

    static func displayVersion(_ tag: String) -> String {
        tag.replacingOccurrences(of: "v", with: "", options: [.anchored])
    }

    static func checkForUpdates() async throws -> UpdateCheckResult {
        guard let url = URL(string: Constants.gitHubLatestReleaseAPI) else {
            throw UpdateCheckError.invalidConfiguration
        }

        var request = URLRequest(url: url, timeoutInterval: 15.0)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("WiFiCheck/\(displayVersion(currentVersionTag()))", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw UpdateCheckError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw UpdateCheckError.unexpectedStatus(httpResponse.statusCode)
            }

            let release = try JSONDecoder().decode(UpdateRelease.self, from: data)
            let currentTag = currentVersionTag()

            logger.info("Update check current=\(currentTag, privacy: .public) latest=\(release.tagName, privacy: .public)")

            if isVersion(release.tagName, newerThan: currentTag) {
                return .updateAvailable(currentTag: currentTag, release: release)
            }

            return .upToDate(currentTag: currentTag)
        } catch {
            logger.error("Update check failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private static func isVersion(_ remoteTag: String, newerThan localTag: String) -> Bool {
        let remote = versionComponents(from: remoteTag)
        let local = versionComponents(from: localTag)
        let componentCount = max(remote.count, local.count)

        for index in 0..<componentCount {
            let remoteValue = index < remote.count ? remote[index] : 0
            let localValue = index < local.count ? local[index] : 0

            if remoteValue != localValue {
                return remoteValue > localValue
            }
        }

        return false
    }

    private static func versionComponents(from tag: String) -> [Int] {
        tag.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "v", with: "", options: [.anchored])
            .split(separator: ".")
            .compactMap { component in
                let digits = component.prefix { $0.isNumber }
                return digits.isEmpty ? nil : Int(digits)
            }
    }
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
        guard day != 0 else { return "??" }
        return day < 10 ? "0\(day)" : "\(day)"
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
    /// - WEP: Orange (weak security)
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
            securityColor = Color(NSColor.systemGreen)
        case .wpa2:
            securityColor = Color(NSColor.systemTeal)
        case .wpa:
            securityColor = Color(NSColor.systemTeal)
        case .wep:
            securityColor = Color(NSColor.systemOrange)
        case .open:
            securityColor = Color(NSColor.systemRed)
        case .unknown:
            securityColor = Color(NSColor.systemGray)
        }
        return securityColor
    }

    /// Returns the frequency band name for a WiFi channel number.
    static func frequencyBand(for channel: Int) -> String {
        switch channel {
        case 1...14:   return "2.4 GHz"
        case 36...177: return "5 GHz"
        default:       return "6 GHz"
        }
    }

    /// Returns the color for a WiFi channel's frequency band.
    /// Uses NSColor-backed system colors so they adapt correctly in both light and dark mode.
    static func getBandColor(for channel: Int) -> Color {
        switch channel {
        case 1...14:  return Color(NSColor.systemOrange)   // 2.4 GHz
        case 36...177: return Color(NSColor.systemBlue)    // 5 GHz
        default:      return Color(NSColor.systemPurple)   // 6 GHz
        }
    }

    /// Returns a date box color that fades from the system accent color toward gray as the date ages.
    ///
    /// - Parameter date: The date to evaluate, or nil for "never"
    /// - Returns: Full accent color for recent dates, blending toward gray for older dates
    static func getDateBoxColor(for date: Date?) -> Color {
        guard let date = date else {
            return Color(NSColor.systemGray)
        }
        let days = Date().timeIntervalSince(date) / 86400
        let fraction: Double
        switch days {
        case ..<7:    fraction = 0.0
        case ..<30:   fraction = 0.15
        case ..<90:   fraction = 0.35
        case ..<180:  fraction = 0.55
        case ..<365:  fraction = 0.75
        default:      fraction = 0.90
        }
        guard let blended = NSColor.controlAccentColor.blended(withFraction: fraction, of: NSColor.systemGray) else {
            return fraction > 0.5 ? Color(NSColor.systemGray) : Color.accentColor
        }
        return Color(blended)
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

        // Set up timeout handler using a lock to safely share the flag across threads
        var didTimeout = false
        let timeoutLock = NSLock()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler {
            if task.isRunning {
                task.terminate()
                timeoutLock.lock()
                didTimeout = true
                timeoutLock.unlock()
            }
        }
        timer.resume()

        // Wait for process to complete
        task.waitUntilExit()
        timer.cancel()

        // Check if process timed out
        timeoutLock.lock()
        let timedOut = didTimeout
        timeoutLock.unlock()
        if timedOut {
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
