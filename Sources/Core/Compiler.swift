// Sources/Core/Compiler.swift
import Foundation

final class Compiler {
    /// Compile and run instrumented code, returning metrics file path
    func compileAndRun(at path: String) async -> CompilationResult {
        let outputBinary = NSTemporaryDirectory() + UUID().uuidString + "_instrumented_binary"
        
        do {
            // Compile
            guard try compile(sourcePath: path, outputPath: outputBinary) else {
                return .failure("Compilation failed")
            }
            
            // Run and capture output
            let output = try await run(binaryPath: outputBinary)
            
            // Print to console for user visibility
            print(output, terminator: "")
            
            // Extract metrics file path from output
            if let metricsPath = extractMetricsPath(from: output) {
                // Cleanup binary
                try? FileManager.default.removeItem(atPath: outputBinary)
                return .success(metricsPath: metricsPath, consoleOutput: output)
            } else {
                // No metrics marker found - fall back to old behavior
                print("\n⚠️  No metrics file detected, using console output parsing")
                try? FileManager.default.removeItem(atPath: outputBinary)
                return .legacyOutput(output)
            }
            
        } catch {
            let errorMsg = "Failed to compile/run instrumented code: \(error)"
            print(errorMsg)
            return .failure(errorMsg)
        }
    }
    
    private func compile(sourcePath: String, outputPath: String) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
        process.arguments = ["-parse-as-library", sourcePath, "-o", outputPath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("Compilation failed:")
                let filtered = output
                    .components(separatedBy: .newlines)
                    .filter { !$0.contains("SWIFT_DEBUG_CONCURRENCY") }
                    .joined(separator: "\n")
                print(filtered)
            }
            return false
        }
        
        return true
    }
    
    private func run(binaryPath: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var output = ""
        
        if let outputString = String(data: data, encoding: .utf8) {
            output = outputString
        }
        
        if process.terminationStatus != 0 {
            output += "\nProcess exited with code: \(process.terminationStatus)"
        }
        
        return output
    }
    
    /// Extract metrics file path from the special marker line
    private func extractMetricsPath(from output: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.hasPrefix("__ASYNC_PROFILER_METRICS__:") {
                let path = line.replacingOccurrences(of: "__ASYNC_PROFILER_METRICS__:", with: "")
                return path.trimmingCharacters(in: .whitespaces)
            }
        }
        
        return nil
    }
}

// MARK: - Result Types

enum CompilationResult {
    case success(metricsPath: String, consoleOutput: String)
    case legacyOutput(String)  // Fallback for old-style console parsing
    case failure(String)
    
    var metricsPath: String? {
        if case .success(let path, _) = self {
            return path
        }
        return nil
    }
    
    var consoleOutput: String {
        switch self {
        case .success(_, let output):
            return output
        case .legacyOutput(let output):
            return output
        case .failure(let error):
            return error
        }
    }
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}