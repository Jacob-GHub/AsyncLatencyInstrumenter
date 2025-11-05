// Sources/Core/Instrumenter.swift
import Foundation
import SwiftParser
import SwiftSyntax
import Models
import Analysis
import Rewriting
import Reporting

public final class Instrumenter {
    private let inputPath: String
    private let scanner: FileScanner
    private let analyzer: AsyncAnalyzer
    private let rewriter: AsyncLatencyRewriter
    private let reporter: Reporter
    private let compiler: Compiler
    private let metricsParser: MetricsParser
    private var capturedMetrics: [FunctionMetric] = []
    
    public init(inputPath: String, 
         reporter: Reporter? = nil,
         instrumentAwaitPoints: Bool = false) {
        self.inputPath = inputPath
        self.scanner = FileScanner(inputPath: inputPath)
        self.analyzer = AsyncAnalyzer()
        self.rewriter = AsyncLatencyRewriter(instrumentAwaitPoints: instrumentAwaitPoints)
        self.reporter = reporter ?? ConsoleReporter()
        self.compiler = Compiler()
        self.metricsParser = MetricsParser()
    }
    
    @discardableResult
    public func run() async -> InstrumentationResults? {
        // Validate path
        guard scanner.validatePath() else {
            print("Error: Path not found: \(inputPath)")
            return nil
        }
        
        // Check if input is already instrumented
        if inputPath.contains("_instrumented") {
            print("⚠️  Warning: Input appears to be already instrumented")
            print("   Please use the original source file, not the *_instrumented.swift file")
            return nil
        }
        
        // NEW: Check if this is a Swift package
        let packageInstrumenter = PackageInstrumenter(packagePath: inputPath)
        if packageInstrumenter.isSwiftPackage() {
            return await runPackageInstrumentation(packageInstrumenter)
        }
        
        // Original behavior for single files/directories
        return await runFileInstrumentation()
    }
    
    // NEW: Handle Swift Package instrumentation
    private func runPackageInstrumentation(_ packageInstrumenter: PackageInstrumenter) async -> InstrumentationResults? {
        do {
            // Instrument and build the package
            let buildResult = try await packageInstrumenter.instrumentAndBuild()
            
            print("\n" + String(repeating: "=", count: 70))
            print("🚀 RUNNING INSTRUMENTED PACKAGE")
            print(String(repeating: "=", count: 70))
            print()
            
            // Run the executable
            let output = try await packageInstrumenter.runExecutable(at: buildResult.executablePath)
            print(output, terminator: "")
            
            // Parse metrics
            let metrics = parseMetricsFromOutput(output)
            capturedMetrics.append(contentsOf: metrics)
            
            // Show statistics
            if !capturedMetrics.isEmpty {
                showStatistics()
            }
            
            // Cleanup
            packageInstrumenter.cleanup()
            
            // Return results
            let summary = ProjectSummary(
                totalFiles: 1,
                filesWithAsync: 1,
                totalAsyncFunctions: metrics.count,
                fileDetails: []
            )
            
            return InstrumentationResults(
                summary: summary,
                executionMetrics: capturedMetrics,
                timestamp: Date()
            )
            
        } catch {
            print("❌ Package instrumentation failed: \(error)")
            packageInstrumenter.cleanup()
            return nil
        }
    }
    
    // Original file-by-file instrumentation
    private func runFileInstrumentation() async -> InstrumentationResults? {
        // Discover files
        let swiftFiles = scanner.discoverSwiftFiles()
        guard !swiftFiles.isEmpty else {
            print("No Swift files found.")
            return nil
        }
        
        if scanner.isDirectory() {
            print("Scanning directory for Swift files...")
            print("Found \(swiftFiles.count) Swift file(s)\n")
        }
        
        // Process files
        let results = await processFiles(swiftFiles)
        
        // Generate summary
        let summary = generateSummary(from: results)
        reporter.report(summary: summary)
        
        // Execute instrumented files
        let executableFiles = results.filter { $0.hasMainAttribute }
        if !executableFiles.isEmpty {
            reporter.reportExecution(message: "Found \(executableFiles.count) executable file(s) with @main attribute\n")
            
            for (index, result) in executableFiles.enumerated() {
                if executableFiles.count > 1 {
                    print("[\(index + 1)/\(executableFiles.count)] Running: \(result.instrumentedPath)")
                    print(String(repeating: "-", count: 70))
                }
                
                let compilationResult = await compiler.compileAndRun(at: result.instrumentedPath)
                
                let metrics = parseMetrics(
                    from: compilationResult,
                    functions: result.asyncFunctions
                )
                capturedMetrics.append(contentsOf: metrics)
                
                if index < executableFiles.count - 1 {
                    print()
                }
            }
            
            if !capturedMetrics.isEmpty {
                showStatistics()
            }
        } else {
            print(String(repeating: "=", count: 70))
            print("ℹ️  No executable files found (no @main attribute detected)")
            print("   Instrumented files have been created with _instrumented.swift suffix")
            print(String(repeating: "=", count: 70))
        }
        
        return InstrumentationResults(
            summary: summary,
            executionMetrics: capturedMetrics,
            timestamp: Date()
        )
    }
    
    // Helper to parse metrics from output (handles both JSON file and console)
    private func parseMetricsFromOutput(_ output: String) -> [FunctionMetric] {
        // Look for metrics file marker
        if let metricsPath = extractMetricsPath(from: output) {
            do {
                let metrics = try metricsParser.parseMetricsFile(at: metricsPath)
                print("\n✅ Parsed \(metrics.count) metrics from structured output")
                try? FileManager.default.removeItem(atPath: metricsPath)
                return metrics
            } catch {
                print("\n⚠️  Failed to parse metrics file: \(error)")
            }
        }
        
        // Fallback to console parsing
        return metricsParser.parseConsoleOutput(output, functions: [])
    }
    
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
    
    private func parseMetrics(
        from result: CompilationResult,
        functions: [AsyncFunctionInfo]
    ) -> [FunctionMetric] {
        switch result {
        case .success(let metricsPath, _):
            do {
                let metrics = try metricsParser.parseMetricsFile(at: metricsPath)
                print("\n✅ Parsed \(metrics.count) metrics from structured output")
                try? FileManager.default.removeItem(atPath: metricsPath)
                return metrics
            } catch {
                print("\n⚠️  Failed to parse metrics file: \(error)")
                return metricsParser.parseConsoleOutput(result.consoleOutput, functions: functions)
            }
            
        case .legacyOutput(let output):
            print("\n📊 Using legacy console output parsing")
            return metricsParser.parseConsoleOutput(output, functions: functions)
            
        case .failure:
            return []
        }
    }
    
    private func showStatistics() {
        let stats = metricsParser.generateStatistics(from: capturedMetrics)
        
        print("\n" + String(repeating: "=", count: 70))
        print("📊 EXECUTION STATISTICS")
        print(String(repeating: "=", count: 70))
        
        print("Total function calls: \(stats.totalFunctions)")
        print("Unique functions: \(stats.uniqueFunctions)")
        print("Total execution time: \(String(format: "%.6f", stats.totalExecutionTime))s")
        print("Average execution time: \(String(format: "%.6f", stats.averageExecutionTime))s")
        
        if !stats.slowestFunctions.isEmpty {
            print("\n🐌 Slowest Functions:")
            for (index, metric) in stats.slowestFunctions.prefix(5).enumerated() {
                print("  \(index + 1). \(metric.name): \(String(format: "%.6f", metric.totalTime))s")
            }
        }
        
        if !stats.mostCalledFunctions.isEmpty {
            print("\n🔥 Most Called Functions:")
            for (index, item) in stats.mostCalledFunctions.prefix(5).enumerated() {
                print("  \(index + 1). \(item.function): \(item.calls) calls")
            }
        }
        
        print(String(repeating: "=", count: 70))
    }
    
    private func processFiles(_ files: [String]) async -> [InstrumentationResult] {
        var results: [InstrumentationResult] = []
        let showProgress = files.count > 10
        
        for (index, filePath) in files.enumerated() {
            if showProgress, let consoleReporter = reporter as? ConsoleReporter {
                consoleReporter.showProgress(current: index + 1, total: files.count)
            }
            
            do {
                let result = try processFile(filePath)
                results.append(result)
            } catch {
                if !showProgress {
                    print("  ⚠️  Failed to process \(filePath): \(error)")
                }
            }
        }
        
        if showProgress, let consoleReporter = reporter as? ConsoleReporter {
            consoleReporter.clearProgress()
        }
        
        return results
    }
    
    private func processFile(_ filePath: String) throws -> InstrumentationResult {
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        
        if source.contains("__AsyncProfilerMetrics") {
            throw InstrumentationError.alreadyInstrumented(filePath)
        }
        
        let tree = Parser.parse(source: source)
        let analysis = analyzer.analyze(sourceFile: tree)
        
        rewriter.setCurrentFile(filePath)
        let instrumented = rewriter.visit(tree)
        
        let outPath = filePath.replacingOccurrences(of: ".swift", with: "_instrumented.swift")
        
        if FileManager.default.fileExists(atPath: outPath) {
            print("   ⚠️  Overwriting existing instrumented file: \(outPath)")
        }
        
        try "\(instrumented)".write(toFile: outPath, atomically: true, encoding: .utf8)
        
        return InstrumentationResult(
            originalPath: filePath,
            instrumentedPath: outPath,
            asyncFunctions: analysis.asyncFunctions,
            hasMainAttribute: analysis.hasMainAttribute
        )
    }
    
    private func generateSummary(from results: [InstrumentationResult]) -> ProjectSummary {
        let filesWithAsync = results.filter { !$0.asyncFunctions.isEmpty }
        let totalAsyncFunctions = results.reduce(0) { $0 + $1.asyncFunctions.count }
        
        let fileDetails = filesWithAsync.map { result in
            FileDetails(
                path: scanner.getRelativePath(result.originalPath),
                asyncFunctionCount: result.asyncFunctions.count,
                functions: result.asyncFunctions.map { $0.fullName }
            )
        }
        
        return ProjectSummary(
            totalFiles: results.count,
            filesWithAsync: filesWithAsync.count,
            totalAsyncFunctions: totalAsyncFunctions,
            fileDetails: fileDetails
        )
    }
}

enum InstrumentationError: Error, LocalizedError {
    case alreadyInstrumented(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyInstrumented(let path):
            return "File is already instrumented: \(path)"
        }
    }
}