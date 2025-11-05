// Sources/Rewriting/AsyncLatencyRewriter.swift
import Foundation
import SwiftSyntax
import SwiftParser

public final class AsyncLatencyRewriter: SyntaxRewriter {
    private let instrumentAwaitPoints: Bool
    private var currentFile: String = ""
    private var nestingDepth: Int = 0
    private var hasInjectedMetrics = false
    private var shouldInjectMetrics = true  // NEW: Control whether to inject

    
    public init(instrumentAwaitPoints: Bool = false) {
        self.instrumentAwaitPoints = instrumentAwaitPoints
        super.init(viewMode: .sourceAccurate)
    }
    
    public func setCurrentFile(_ path: String) {
        self.currentFile = path
        self.hasInjectedMetrics = false
    }

    public func setShouldInjectMetrics(_ should: Bool) {
        self.shouldInjectMetrics = should
    }
    
    // MARK: - Inject Metrics Library
    
    public override func visit(_ node: SourceFileSyntax) -> SourceFileSyntax {
        var newStatements = node.statements
        
        // Inject the metrics collector at the top of the file (only once)
        if !hasInjectedMetrics && shouldInjectMetrics {
            let metricsCode = generateMetricsCollector()
            let metricsTree = Parser.parse(source: metricsCode)
            
            var updatedStatements = metricsTree.statements
            
            // Add the original statements, but ensure proper spacing
            // by adding leading trivia (newlines) to the first original statement
            if let firstOriginal = newStatements.first {
                // Add two newlines before the first statement of the original file
                let withTrivia = firstOriginal.with(\.leadingTrivia, .newlines(2) + firstOriginal.leadingTrivia)
                var modifiedStatements = CodeBlockItemListSyntax()
                modifiedStatements.append(withTrivia)
                modifiedStatements.append(contentsOf: newStatements.dropFirst())
                newStatements = modifiedStatements
            }
            
            updatedStatements.append(contentsOf: newStatements)
            newStatements = updatedStatements
            hasInjectedMetrics = true
        }
        
        // Continue visiting children
        return super.visit(node.with(\.statements, newStatements))
    }
    
    private func generateMetricsCollector() -> String {
        return """
        import Foundation

        // Auto-injected metrics collector
        final class __AsyncProfilerMetrics {
            static let shared = __AsyncProfilerMetrics()
            
            private var metrics: [MetricEntry] = []
            private let lock = NSLock()
            private let outputPath: String
            
            struct MetricEntry: Codable {
                let function: String
                let duration: Double
                let timestamp: Double
                let line: Int
                let file: String
                let threadID: UInt64
            }
            
            private init() {
                let pid = ProcessInfo.processInfo.processIdentifier
                self.outputPath = "/tmp/async_profile_\\(pid).json"
                try? FileManager.default.removeItem(atPath: outputPath)
                
                // Register flush to be called at program exit
                atexit {
                    __AsyncProfilerMetrics.shared.flush()
                }
            }
            
            func record(function: String, duration: Double, line: Int, file: String) {
                lock.lock()
                defer { lock.unlock() }
                
                metrics.append(MetricEntry(
                    function: function,
                    duration: duration,
                    timestamp: Date().timeIntervalSince1970,
                    line: line,
                    file: file,
                    threadID: UInt64(pthread_mach_thread_np(pthread_self()))
                ))
            }
            
            func flush() {
                lock.lock()
                let entries = metrics
                lock.unlock()
                
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(entries)
                    try data.write(to: URL(fileURLWithPath: outputPath))
                    print("__ASYNC_PROFILER_METRICS__:\\(outputPath)")
                } catch {
                    print("Failed to write metrics: \\(error)")
                }
            }
        }

        // Trigger initialization to register atexit handler
        private let __metricsInitializer = __AsyncProfilerMetrics.shared
        """
    }
    
    // MARK: - Instrument Functions
    
    public override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        // Only instrument async functions
        guard node.signature.effectSpecifiers?.asyncSpecifier != nil else {
            return DeclSyntax(node)
        }
        
        nestingDepth += 1
        defer { nestingDepth -= 1 }
        
        guard let body = node.body else {
            return DeclSyntax(node)
        }
        
        let functionName = node.name.text
        let lineNumber = node.position.utf8Offset // Approximate line number
        let fileName = (currentFile as NSString).lastPathComponent
        
        // Create instrumentation code
        let instrumentedBody = createInstrumentedBody(
            originalBody: body,
            functionName: functionName,
            line: lineNumber,
            file: fileName
        )
        
        // Return function with new body
        return DeclSyntax(node.with(\.body, instrumentedBody))
    }
    
    private func createInstrumentedBody(
        originalBody: CodeBlockSyntax,
        functionName: String,
        line: Int,
        file: String
    ) -> CodeBlockSyntax {
        // Build complete instrumentation as one code block with leading newline
        let instrumentationCode = """
        
        let __start_\(functionName) = ContinuousClock.now
        defer {
            let __end = ContinuousClock.now
            let __duration = __start_\(functionName).duration(to: __end)
            let __seconds = Double(__duration.components.seconds) + Double(__duration.components.attoseconds) / 1e18
            __AsyncProfilerMetrics.shared.record(
                function: "\(functionName)",
                duration: __seconds,
                line: \(line),
                file: "\(file)"
            )
        }
        """
        
        // Parse instrumentation code
        let instrumentTree = Parser.parse(source: instrumentationCode)
        
        // Combine: instrumentation + original body
        var newStatements = CodeBlockItemListSyntax()
        newStatements += instrumentTree.statements
        newStatements += originalBody.statements
        
        return originalBody.with(\.statements, newStatements)
    }
}