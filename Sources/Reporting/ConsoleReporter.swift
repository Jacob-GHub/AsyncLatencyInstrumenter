// Sources/Reporting/ConsoleReporter.swift
import Foundation
import Models

public final class ConsoleReporter: Reporter {
    private let showProgress: Bool
    private let useColors: Bool
    
    private enum Color: String {
        case reset = "\u{001B}[0m"
        case red = "\u{001B}[31m"
        case green = "\u{001B}[32m"
        case yellow = "\u{001B}[33m"
        case blue = "\u{001B}[34m"
        case magenta = "\u{001B}[35m"
        case cyan = "\u{001B}[36m"
        case bold = "\u{001B}[1m"
        case dim = "\u{001B}[2m"
    }
    
    public init(showProgress: Bool = true, useColors: Bool = true) {
        self.showProgress = showProgress
        self.useColors = useColors
    }
    
    public func report(summary: ProjectSummary) {
        printSeparator()
        printColored("INSTRUMENTATION SUMMARY", color: .cyan, bold: true)
        printSeparator()
        
        print("Total files processed: \(colorize("\(summary.totalFiles)", color: .blue))")
        print("Files with async functions: \(colorize("\(summary.filesWithAsync)", color: .green))")
        print("Total async functions found: \(colorize("\(summary.totalAsyncFunctions)", color: .magenta))")
        print()
        
        if !summary.fileDetails.isEmpty {
            printDivider()
            printColored("FILES WITH ASYNC FUNCTIONS:", color: .cyan, bold: true)
            printDivider()
            
            let sorted = summary.fileDetails.sorted { $0.asyncFunctionCount > $1.asyncFunctionCount }
            
            for (index, file) in sorted.prefix(20).enumerated() {
                print("\n[\(colorize("\(index + 1)", color: .yellow))] \(colorize(file.path, color: .blue))")
                
                let countColor: Color = file.asyncFunctionCount > 10 ? .red : (file.asyncFunctionCount > 5 ? .yellow : .green)
                print("    \(colorize("\(file.asyncFunctionCount)", color: countColor)) async function(s):")
                
                for funcName in file.functions.prefix(5) {
                    print("    • \(funcName)")
                }
                
                if file.functions.count > 5 {
                    print("    \(colorize("... and \(file.functions.count - 5) more", color: .dim))")
                }
            }
            
            if sorted.count > 20 {
                print("\n\(colorize("... and \(sorted.count - 20) more files", color: .dim))")
            }
        } else {
            print("ℹ️  No async functions found.")
        }
        
        print()
    }
    
    public func reportExecution(message: String) {
        printSeparator()
        printColored("RUNNING INSTRUMENTED CODE", color: .cyan, bold: true)
        printSeparator()
        print(message)
    }
    
    public func showProgress(current: Int, total: Int) {
        guard showProgress && total > 10 else { return }
        
        let progress = Float(current) / Float(total) * 100
        let bar = progressBar(percent: Int(progress))
        print("\r\(colorize("Processing:", color: .cyan)) [\(bar)] \(Int(progress))% (\(current)/\(total))", terminator: "")
        fflush(stdout)
    }
    
    public func clearProgress() {
        guard showProgress else { return }
        print("\r" + String(repeating: " ", count: 80))
        print("\r", terminator: "")
    }
    
    // MARK: - Helper Methods
    
    private func progressBar(percent: Int, width: Int = 30) -> String {
        let filled = Int(Double(percent) / 100.0 * Double(width))
        let empty = width - filled
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
        
        if percent < 33 {
            return colorize(bar, color: .red)
        } else if percent < 66 {
            return colorize(bar, color: .yellow)
        } else {
            return colorize(bar, color: .green)
        }
    }
    
    private func printSeparator() {
        print(colorize(String(repeating: "=", count: 70), color: .cyan))
    }
    
    private func printDivider() {
        print(colorize(String(repeating: "-", count: 70), color: .dim))
    }
    
    private func printColored(_ text: String, color: Color, bold: Bool = false) {
        if bold {
            print("\(Color.bold.rawValue)\(colorize(text, color: color))")
        } else {
            print(colorize(text, color: color))
        }
    }
    
    private func colorize(_ text: String, color: Color) -> String {
        guard useColors else { return text }
        return "\(color.rawValue)\(text)\(Color.reset.rawValue)"
    }
}