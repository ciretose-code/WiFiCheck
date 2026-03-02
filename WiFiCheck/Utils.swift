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
    
    static func dateToString(_ d: Date?) -> String? {
        if d == nil {
            return nil
        }
        let df: DateFormatter = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return df.string(from: d!)
    }
    
    static func relativeDateToString(_ d: Date?) -> String? {
        if d == nil {
            return nil
        }
        let rdf: RelativeDateTimeFormatter = RelativeDateTimeFormatter()
        rdf.unitsStyle = .full
        let check = Calendar.current.date(byAdding: .month, value: -9, to: Date())
        if check != nil && d!.moreRecentThan(check!) {
            return rdf.localizedString(for: d!, relativeTo: Date())
        } else {
            return "\(Utils.getDayString(d)) "+"\(Utils.getMonthShort(d)) "+"\(Utils.getYear(d))"
        }
    }
    
    static func getTime(_ d: Date?) -> String {
        if d == nil {
            return ""
        }
        let df: DateFormatter = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        
        return df.string(from: d!)
    }
    
    static func getDay(_ d: Date?) -> Int {
        if d == nil {
            return 0
        }
        let cal = Calendar.current
        return cal.component(.day, from: d!)
    }
    
    static func getMonthShort(_ d: Date?) -> String {
        if d == nil {
            return "???"
        }
        let df = DateFormatter()
        df.dateFormat = "MMM"
        return df.string(from: d!)
    }
    
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
    
    static func getYear(_ d: Date?) -> Int {
        if d == nil {
            return 0
        }
        let cal = Calendar.current
        return cal.component(.year, from: d!)
    }
    
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
    
    static func getDateBoxColor(_ wifidata: WiFiData, _ d: Date?) -> Color {
        if d == nil {
            return Color.gray
        } else {
            return getSecurityColor(wifidata)
        }
    }
    
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

