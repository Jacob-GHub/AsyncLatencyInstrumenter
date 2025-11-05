// Sources/Runtime/MetricsCollector.swift
// This gets injected into instrumented code

import Foundation

/// Thread-safe metrics collector that writes to a JSON file
/// instead of relying on stdout parsing
final class __AsyncProfilerMetrics {
    static let shared = __AsyncProfilerMetrics()
    
    private var metrics: [MetricEntry] = []
    private let lock = NSLock()
    private let outputPath: String
    private let processID: Int32
    
    struct MetricEntry: Codable {
        let function: String
        let duration: Double
        let timestamp: Double
        let line: Int
        let file: String
        let threadID: UInt64
        let depth: Int
    }
    
    private init() {
        self.processID = ProcessInfo.processInfo.processIdentifier
        self.outputPath = "/tmp/async_profile_\(processID).json"
        
        // Clean up old metrics file if it exists
        try? FileManager.default.removeItem(atPath: outputPath)
    }
    
    /// Record a function execution
    func record(
        function: String,
        duration: Double,
        line: Int,
        file: String,
        depth: Int = 0
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        let entry = MetricEntry(
            function: function,
            duration: duration,
            timestamp: Date().timeIntervalSince1970,
            line: line,
            file: file,
            threadID: pthread_mach_thread_np(pthread_self()),
            depth: depth
        )
        
        metrics.append(entry)
    }
    
    /// Save metrics to disk and print the file path
    func flush() {
        lock.lock()
        let entries = metrics
        lock.unlock()
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(entries)
            try data.write(to: URL(fileURLWithPath: outputPath))
            
            // Print a special marker that the instrumenter can detect
            print("__ASYNC_PROFILER_METRICS__:\(outputPath)")
        } catch {
            print("Failed to write metrics: \(error)")
        }
    }
    
    /// Get metrics file path without flushing
    var metricsFilePath: String {
        return outputPath
    }
}

// Automatic cleanup when process exits
private class MetricsCleanup {
    deinit {
        __AsyncProfilerMetrics.shared.flush()
    }
}

private let _cleanup = MetricsCleanup()