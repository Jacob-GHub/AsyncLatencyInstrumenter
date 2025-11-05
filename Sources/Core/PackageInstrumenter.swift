// Sources/Core/PackageInstrumenter.swift
import Foundation
import SwiftParser
import SwiftSyntax
import Rewriting
import Analysis
import Models
import Reporting

/// Handles instrumentation of entire Swift packages
final class PackageInstrumenter {
    private let packagePath: String
    private let workingDirectory: String
    
    init(packagePath: String) {
        self.packagePath = packagePath
        self.workingDirectory = NSTemporaryDirectory() + "async_profiler_\(UUID().uuidString)"
    }
    
    /// Detect if path is a Swift package
    func isSwiftPackage() -> Bool {
        let packageFile = (packagePath as NSString).appendingPathComponent("Package.swift")
        return FileManager.default.fileExists(atPath: packageFile)
    }
    
    /// Instrument entire package and build it
    func instrumentAndBuild() async throws -> PackageBuildResult {
        print("📦 Detected Swift Package at: \(packagePath)")
        
        // 1. Create working directory
        try FileManager.default.createDirectory(
            atPath: workingDirectory,
            withIntermediateDirectories: true
        )
        
        // 2. Copy entire package to working directory
        print("📋 Copying package to temporary location...")
        try copyPackage()
        
        // 3. Instrument all Swift files in Sources/
        print("🔧 Instrumenting Swift files...")
        let instrumentedCount = try await instrumentSourceFiles()
        print("✅ Instrumented \(instrumentedCount) file(s)")
        
        // 4. Build the instrumented package
        print("🏗️  Building instrumented package...")
        let buildResult = try await buildPackage()
        
        return buildResult
    }
    
    /// Copy package to working directory
    private func copyPackage() throws {
        let fm = FileManager.default
        
        // Copy Package.swift
        let packageSwift = (packagePath as NSString).appendingPathComponent("Package.swift")
        let destPackageSwift = (workingDirectory as NSString).appendingPathComponent("Package.swift")
        try fm.copyItem(atPath: packageSwift, toPath: destPackageSwift)
        
        // Copy Sources/ directory
        let sourcesPath = (packagePath as NSString).appendingPathComponent("Sources")
        if fm.fileExists(atPath: sourcesPath) {
            let destSources = (workingDirectory as NSString).appendingPathComponent("Sources")
            try fm.copyItem(atPath: sourcesPath, toPath: destSources)
        }
        
        // Copy Tests/ if exists (optional)
        let testsPath = (packagePath as NSString).appendingPathComponent("Tests")
        if fm.fileExists(atPath: testsPath) {
            let destTests = (workingDirectory as NSString).appendingPathComponent("Tests")
            try? fm.copyItem(atPath: testsPath, toPath: destTests)
        }
        
        // Copy Package.resolved if exists (for dependency locking)
        let packageResolved = (packagePath as NSString).appendingPathComponent("Package.resolved")
        if fm.fileExists(atPath: packageResolved) {
            let destResolved = (workingDirectory as NSString).appendingPathComponent("Package.resolved")
            try? fm.copyItem(atPath: packageResolved, toPath: destResolved)
        }
        
        // NEW: Copy .build directory if it exists (reuse dependency cache)
        let buildPath = (packagePath as NSString).appendingPathComponent(".build")
        if fm.fileExists(atPath: buildPath) {
            print("   📦 Found existing .build cache, copying to speed up build...")
            let destBuild = (workingDirectory as NSString).appendingPathComponent(".build")
            do {
                try fm.copyItem(atPath: buildPath, toPath: destBuild)
                print("   ✅ Build cache copied successfully")
            } catch {
                print("   ⚠️  Could not copy build cache (will rebuild from scratch): \(error)")
            }
        }
    }
    
    /// Instrument all Swift files in Sources/
    private func instrumentSourceFiles() async throws -> Int {
        let sourcesPath = (workingDirectory as NSString).appendingPathComponent("Sources")
        let scanner = FileScanner(inputPath: sourcesPath)
        let swiftFiles = scanner.discoverSwiftFiles()
        
        guard !swiftFiles.isEmpty else {
            throw PackageError.noSwiftFiles
        }
        
        let rewriter = AsyncLatencyRewriter(instrumentAwaitPoints: false)
        var instrumentedCount = 0
        
        // NEW: Track if we've injected metrics yet (do it only in first file)
        var hasInjectedMetrics = false
        
        for filePath in swiftFiles {
            do {
                let source = try String(contentsOfFile: filePath, encoding: .utf8)
                
                // Skip if already instrumented
                if source.contains("__AsyncProfilerMetrics") {
                    continue
                }
                
                let tree = Parser.parse(source: source)
                rewriter.setCurrentFile(filePath)
                
                // NEW: Only inject metrics collector in the FIRST file
                if !hasInjectedMetrics {
                    rewriter.setShouldInjectMetrics(true)
                    hasInjectedMetrics = true
                } else {
                    rewriter.setShouldInjectMetrics(false)
                }
                
                let instrumented = rewriter.visit(tree)
                
                // Overwrite original file (we're in temp directory)
                try "\(instrumented)".write(toFile: filePath, atomically: true, encoding: .utf8)
                instrumentedCount += 1
            } catch {
                print("⚠️  Failed to instrument \(filePath): \(error)")
            }
        }
        
        return instrumentedCount
    }
    
    /// Build package using swift build
    private func buildPackage() async throws -> PackageBuildResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["build", "--package-path", workingDirectory, "-c", "release"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        print("   Running: swift build --package-path \(workingDirectory) -c release")
        print("   This may take several minutes for large projects with dependencies...")
        print("   (You can monitor progress in another terminal with: tail -f /tmp/async_profiler_build.log)")
        
        // Create a file to log build output
        let logPath = "/tmp/async_profiler_build.log"
        FileManager.default.createFile(atPath: logPath, contents: nil)
        let logHandle = FileHandle(forWritingAtPath: logPath)
        
        // Read output in background to show progress
        let outputTask = Task {
            var lastUpdate = Date()
            for try await line in outputPipe.fileHandleForReading.bytes.lines {
                // Write to log file
                if let data = (line + "\n").data(using: .utf8) {
                    try? logHandle?.write(contentsOf: data)
                }
                
                // Show periodic progress (every 5 seconds)
                if Date().timeIntervalSince(lastUpdate) > 5 {
                    print("   [Building...] \(line.prefix(60))")
                    lastUpdate = Date()
                }
            }
        }
        
        let errorTask = Task {
            for try await line in errorPipe.fileHandleForReading.bytes.lines {
                // Write to log file
                if let data = (line + "\n").data(using: .utf8) {
                    try? logHandle?.write(contentsOf: data)
                }
                
                // Show errors immediately
                if line.contains("error:") || line.contains("warning:") {
                    print("   ⚠️  \(line)")
                }
            }
        }
        
        try process.run()
        
        // Wait for process with timeout
        let startTime = Date()
        while process.isRunning {
            try await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5s
            
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 600 { // 10 minute timeout
                process.terminate()
                throw PackageError.buildFailed("Build timeout after 10 minutes")
            }
            
            // Show progress every 30 seconds
            if Int(elapsed) % 30 == 0 && Int(elapsed) > 0 {
                print("   [Still building... \(Int(elapsed))s elapsed]")
            }
        }
        
        process.waitUntilExit()
        
        // Wait for output tasks to finish
        try? await outputTask.value
        try? await errorTask.value
        try? logHandle?.close()
        
        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        
        guard process.terminationStatus == 0 else {
            print("\n❌ Build failed. Check log at: \(logPath)")
            throw PackageError.buildFailed(errorOutput)
        }
        
        print("   ✅ Build completed successfully")
        
        // Find the built executable
        let executablePath = try findExecutable()
        
        return PackageBuildResult(
            executablePath: executablePath,
            workingDirectory: workingDirectory,
            buildOutput: output
        )
    }
    
    /// Find the built executable in .build/release/
    private func findExecutable() throws -> String {
        let buildPath = (workingDirectory as NSString).appendingPathComponent(".build/release")
        
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: buildPath) else {
            throw PackageError.executableNotFound
        }
        
        // Look for executable file (not .swiftmodule, .build, etc.)
        for file in contents {
            let fullPath = (buildPath as NSString).appendingPathComponent(file)
            
            // Check if file is executable
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir)
            
            if !isDir.boolValue && FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        
        throw PackageError.executableNotFound
    }
    
    /// Run the built executable and capture metrics
    func runExecutable(at path: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Cleanup temporary directory
    func cleanup() {
        try? FileManager.default.removeItem(atPath: workingDirectory)
    }
}

// MARK: - Result Types

struct PackageBuildResult {
    let executablePath: String
    let workingDirectory: String
    let buildOutput: String
}

enum PackageError: Error, LocalizedError {
    case noSwiftFiles
    case buildFailed(String)
    case executableNotFound
    
    var errorDescription: String? {
        switch self {
        case .noSwiftFiles:
            return "No Swift files found in Sources/"
        case .buildFailed(let output):
            return "Package build failed:\n\(output)"
        case .executableNotFound:
            return "Could not find built executable in .build/release/"
        }
    }
}