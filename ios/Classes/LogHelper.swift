//
//  LogHelper.swift
//
//  Created by Umair Adil on 10/11/2020.
//

import Foundation
import ZIPFoundation

class LogHelper: NSObject {
    
    static var TAG = "LogHelper"
    
    //MARK: constants
    static let sharedInstance = LogHelper()

    /// Matches the timestamp written by `prefix()` at the start of each log entry,
    /// e.g. "2026-10-14 10:00:00.123 +0200: {tag} {subTag} {logMessage} {level}".
    private static let logEntryStartRegex = try! NSRegularExpression(pattern: "^\\d+-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}\\.\\d{3}: ")

    static var logFilePath: String {
        return ""
    }
    
    static func initLogs(result: @escaping FlutterResult){
        print("initLogs")
        
    }
    
    static func logToFile(result: @escaping FlutterResult, logFileName:String, message:String,
                          overwrite:Bool, appendTimeStamp:Bool){
        let log = "{\(logFileName)} {\(message)} {\(overwrite)}"
        
        guard let dirURL = Logging.defaultLogsDirectoryURL() else {
            print("Logs directory not found")
            return
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "y-MM"
        
        let fileName = "\(logFileName)-\(dateFormatter.string(from: Date()))"
        let fileURL = dirURL.appendingPathComponent(fileName).appendingPathExtension("txt")
        let output = FileOutput(filePath: fileURL.path)
        Logger.sharedInstance.addOutput(output)
        Logger.sharedInstance.log(prefix() + ": " + log)
        result(log)
    }
    
    static func logThis(result: @escaping FlutterResult,
                        tag:String,
                        subTag:String,
                        logMessage:String,
                        level:String){
        let log = "{\(tag)} {\(subTag)} {\(logMessage)} {\(level)}"
        
        guard let dirURL = Logging.defaultLogsDirectoryURL() else {
            print("Logs directory not found")
            return
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "y-MM"
        
        let fileName = "Log-\(dateFormatter.string(from: Date()))"
        let fileURL = dirURL.appendingPathComponent(fileName).appendingPathExtension("txt")
        let output = FileOutput(filePath: fileURL.path)
        Logger.sharedInstance.addOutput(output)
        Logger.sharedInstance.log(prefix() + ": " + log)
        result(log)
    }
    
    static func logThis(result: @escaping FlutterResult,
                        tag:String,
                        subTag:String,
                        logMessage:String,
                        level:String,
                        exception:String){
        let log = "{\(tag)} {\(subTag)} {\(logMessage)} {\(level)}"
        guard let dirURL = Logging.defaultLogsDirectoryURL() else {
            print("Logs directory not found")
            return
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "y-MM"
        
        let fileName = "Log-\(dateFormatter.string(from: Date()))"
        let fileURL = dirURL.appendingPathComponent(fileName).appendingPathExtension("txt")
        let output = FileOutput(filePath: fileURL.path)
        Logger.sharedInstance.addOutput(output)
        Logger.sharedInstance.log(prefix() + ": " + log)
        result(log)
    }
    
    static func getFiles(result: @escaping FlutterResult,eventSink: FlutterEventSink?,channel : FlutterMethodChannel?){
        guard let files = Logging.fileURLs  else {
            result("{\(TAG)} {getFiles} {No Files found!} {\(getTimeStamp())}")
            return
        }
        
        if(!files.isEmpty){
            
            files.forEach { (fileURL) in
                print(fileURL.absoluteURL)
            }
            
            zipLogs(result: result, zipName: "logs",eventSink:eventSink, channel:channel)
        }else{
            result("{\(TAG)} {getFiles} {No Files found!} {\(getTimeStamp())}")
        }
    }
    
    static func exportFilteredLogs(result: @escaping FlutterResult,
                                   keywords: [String],
                                   filterType: String,
                                   ignoreCase: Bool,
                                   exportType: String?,
                                   decryptBeforeExporting: Bool,
                                   eventSink: FlutterEventSink?,
                                   channel: FlutterMethodChannel?){
        if let exportType = exportType, exportType != "ALL" {
            print("{\(TAG)} {exportFilteredLogs} {Warning: exportType '\(exportType)' is not supported on iOS and will be ignored. All logs are filtered.} {\(getTimeStamp())}")
        }
        if decryptBeforeExporting {
            print("{\(TAG)} {exportFilteredLogs} {Warning: decryptBeforeExporting has no effect on iOS, logs are not encrypted.} {\(getTimeStamp())}")
        }

        let keywords = keywords.filter { !$0.isEmpty }
        if keywords.isEmpty {
            result("{\(TAG)} {exportFilteredLogs} {No keywords given!} {\(getTimeStamp())}")
            return
        }

        guard let files = Logging.fileURLs, !files.isEmpty else {
            result("{\(TAG)} {exportFilteredLogs} {No Files found!} {\(getTimeStamp())}")
            return
        }

        let filtered: (hasMatches: Bool, filteredLogs: URL)
        do {
            filtered = try findFilteredLogs(files: files, keywords: keywords, filterType: filterType, ignoreCase: ignoreCase)
        } catch {
            print(error)
            result("{\(TAG)} {exportFilteredLogs} {Unable to write filtered logs!} {\(getTimeStamp())}")
            return
        }
        
        defer { try? FileManager.default.removeItem(at: filtered.filteredLogs) }

        if !filtered.hasMatches {
            result("{\(TAG)} {exportFilteredLogs} {No matching logs found!} {\(getTimeStamp())}")
            return
        }

        zipLogs(result: result, zipName: "filtered_logs", sourceDirectoryURL: filtered.filteredLogs, eventSink:eventSink, channel:channel)
    }

    static func printLogs(result: @escaping FlutterResult,eventSink: FlutterEventSink?,channel : FlutterMethodChannel?){
        
        guard let files = Logging.fileURLs  else {
            result("{\(TAG)} {printLogs} {No Files found!} {\(getTimeStamp())}")
            return
        }
        
        if(!files.isEmpty){
            
            files.forEach { (fileURL) in
                //reading
                do {
                    let text2 = try String(contentsOf: fileURL, encoding: .utf8)
                    result("{\(TAG)} {printLogs} {Printed: \(text2)} {\(getTimeStamp())}")
                    channel?.invokeMethod("logsPrinted", arguments: text2)
                }
                catch {
                    print(error)
                    result("{\(TAG)} {printLogs} {Unable to read file. \(fileURL)} {\(getTimeStamp())}")
                }
            }
        }else{
            result("{\(TAG)} {printLogs} {No Files found!} {\(getTimeStamp())}")
        }
    }
    
    static func clearLogs(result: @escaping FlutterResult){
        let documentsUrl = Logging.defaultLogsDirectoryURL()
        let fileManager = FileManager.default
        do {
            let directoryContents = try fileManager.contentsOfDirectory(at: documentsUrl!, includingPropertiesForKeys: nil)
            
            let files = directoryContents
            
            for url in files {
                print("{\(TAG)} {clearLogs} {Cleared: \(url.absoluteString) {\(getTimeStamp())}")
                try fileManager.removeItem(at: url)
            }
            
//            let outputPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask,true)
//
//            for url in outputPath {
//                let u = URL(fileURLWithPath: url)
//                print("{\(TAG)} {clearLogs} {Cleared: \(u) {\(getTimeStamp())}")
//                try fileManager.removeItem(at: u)
//            }
            
            result("{\(TAG)} {clearLogs} {Logs Cleared!)} {\(getTimeStamp())}")
        } catch {
            print(error)
            result("{\(TAG)} {clearLogs} {No Logs found! )} {\(getTimeStamp())}")
        }
    }
    
    static func getTimeStamp()->String{
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.string(from: date)
    }
    
    static var _dateFormatter: DateFormatter?
    static func dateFormatter() -> DateFormatter {
        if _dateFormatter == nil {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "y-MM-dd HH:mm:ss.SSS Z"
            _dateFormatter = dateFormatter
        }
        return _dateFormatter!
    }
    
    static func prefix() -> String {
        return dateFormatter().string(from: Date())
    }
    
    static func zipLogs(result: @escaping FlutterResult, zipName:String, sourceDirectoryURL: URL? = Logging.defaultLogsDirectoryURL(), eventSink: FlutterEventSink?,channel : FlutterMethodChannel?) {

        let  path = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask,true).first!

        guard var sourceURL = sourceDirectoryURL  else {
            print("{\(TAG)} {zipData} {Dir not found!} {\(getTimeStamp())}")
            result("{\(TAG)} {zipData} {Dir not found!} {\(getTimeStamp())}")
            return
        }
        
        let zipName = "\(zipName)_\(getTimeStamp()).zip"
        
        var destinationURL = URL(fileURLWithPath: path)
        destinationURL.appendPathComponent(zipName)
        
        do {
            let fm = FileManager.default
            let items = try fm.contentsOfDirectory(atPath: sourceURL.path)
            
            guard let archive = Archive(url: destinationURL, accessMode: .create) else  {
                print("Unable to create an Archive!")
                result("Unable to create an Archive!")
                return
            }
            
            for item in items {
                print("Adding to Zip: \(item)")
                sourceURL = sourceURL.appendingPathComponent("/\(item)")
                
                try archive.addEntry(with: sourceURL.lastPathComponent, relativeTo: sourceURL.deletingLastPathComponent(), compressionMethod: CompressionMethod.deflate)
                
                guard Archive(url: destinationURL, accessMode: .update) != nil else  {
                    print("Unable to update the Archive!")
                    result("Unable to update the Archive!")
                    return
                }
                
                sourceURL.deleteLastPathComponent()
            }
            
            print("{\(TAG)} {zipLogs} {Zip created: \(destinationURL.lastPathComponent)} {\(getTimeStamp())}")
            
            result(destinationURL.lastPathComponent)
            channel?.invokeMethod("logsExported", arguments: "\(destinationURL.lastPathComponent)")
        } catch {
            print("{\(TAG)} {zipLogs} {No Files found!} {\(getTimeStamp())}")
            result("{\(TAG)} {zipLogs} {No Files found!} {\(getTimeStamp())}")
        }
    }

    /// Writes all log entries containing the keywords to a temporary directory.
    /// The caller is responsible for removing the returned directory.
    private static func findFilteredLogs(files: [URL],
                                         keywords: [String],
                                         filterType: String,
                                         ignoreCase: Bool) throws -> (hasMatches: Bool, filteredLogs: URL) {
        // Matching entries are written to a temporary directory, which is then zipped like the regular export
        let fm = FileManager.default
        let filteredDirURL = fm.temporaryDirectory.appendingPathComponent("filtered_logs_\(UUID().uuidString)")

        var hasMatches = false
        do {
            try fm.createDirectory(at: filteredDirURL, withIntermediateDirectories: true, attributes: nil)

            for fileURL in files {
                guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
                    print("{\(TAG)} {exportFilteredLogs} {Unable to read file. \(fileURL)} {\(getTimeStamp())}")
                    continue
                }

                let matchingEntries = logEntries(in: text).filter({ logEntryMatches(entry: $0, keywords: keywords, filterType: filterType, ignoreCase: ignoreCase) })
                if matchingEntries.isEmpty {
                    continue
                }

                hasMatches = true
                let filteredText = matchingEntries.joined(separator: "\n") + "\n"
                try filteredText.write(to: filteredDirURL.appendingPathComponent(fileURL.lastPathComponent), atomically: true, encoding: .utf8)
            }
        } catch {
            try? fm.removeItem(at: filteredDirURL)
            throw error
        }

        return (hasMatches, filteredDirURL)
    }
    
    /// Splits the log text into entries. An entry starts with a timestamp and includes all
    /// following lines without a timestamp (e.g. stack traces) up to the next entry.
    private static func logEntries(in text: String) -> [String] {
        var entries: [String] = []
        var currentEntryLines: [String] = []

        text.enumerateLines { line, _ in
            if isLogEntryStart(line), !currentEntryLines.isEmpty {
                entries.append(currentEntryLines.joined(separator: "\n"))
                currentEntryLines = []
            }
            currentEntryLines.append(line)
        }

        if !currentEntryLines.isEmpty {
            entries.append(currentEntryLines.joined(separator: "\n"))
        }
        return entries
    }

    private static func isLogEntryStart(_ line: String) -> Bool {
        return logEntryStartRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
    }

    private static func logEntryMatches(entry: String,
                                        keywords: [String],
                                        filterType: String,
                                        ignoreCase: Bool) -> Bool {
        let matchesFilter = { (keyword: String) -> Bool in
            entry.range(of: keyword, options: ignoreCase ? .caseInsensitive : []) != nil
        }
        return filterType == "AND"
                ? keywords.allSatisfy(matchesFilter)
                : keywords.contains(where: matchesFilter)
    }
}
