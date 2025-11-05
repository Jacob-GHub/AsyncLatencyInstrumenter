// Sources/Core/MetricsParser.swift
import Foundation
import Models

/// Parses the structured JSON metrics file instead of console output
final class MetricsParser {
    
    struct RawMetric: Codable {
        let function: String
        let duration: Double
        let timestamp: Double
        let line: Int
        let file: String
        let threadID: UInt64
    }
    
    /// Parse metrics from the JSON file written by the instrumented code
    func parseMetricsFile(at path: String) throws -> [FunctionMetric] {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        let rawMetrics = try decoder.decode([RawMetric].self, from: data)
        
        // Convert to FunctionMetric
        return rawMetrics.map { raw in
            FunctionMetric(
                name: raw.function,
                totalTime: raw.duration,
                computeTime: nil,  // Not yet implemented
                suspendTime: nil,  // Not yet implemented
                awaitCount: nil,   // Not yet implemented
                depth: estimateDepth(for: raw.function)
            )
        }
    }
    
    /// Legacy fallback: parse console output (old behavior)
    func parseConsoleOutput(_ output: String, functions: [AsyncFunctionInfo]) -> [FunctionMetric] {
        var metrics: [FunctionMetric] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // Look for lines like: [Latency] fetchUser: 0.106556s
            if line.contains("[Latency]") {
                let components = line.components(separatedBy: ": ")
                guard components.count == 2 else { continue }
                
                let nameComponent = components[0].replacingOccurrences(of: "[Latency] ", with: "")
                let timeComponent = components[1].replacingOccurrences(of: "s", with: "")
                
                if let time = Double(timeComponent) {
                    let depth = estimateDepth(for: nameComponent)
                    
                    metrics.append(FunctionMetric(
                        name: nameComponent,
                        totalTime: time,
                        depth: depth
                    ))
                }
            }
        }
        
        return metrics
    }
    
    /// Generate statistics from metrics
    func generateStatistics(from metrics: [FunctionMetric]) -> MetricsStatistics {
        let totalTime = metrics.reduce(0.0) { $0 + $1.totalTime }
        let avgTime = metrics.isEmpty ? 0.0 : totalTime / Double(metrics.count)
        
        let sorted = metrics.sorted { $0.totalTime > $1.totalTime }
        let slowest = Array(sorted.prefix(10))
        
        // Group by function name to detect multiple calls
        var callCounts: [String: Int] = [:]
        var totalDurations: [String: Double] = [:]
        
        for metric in metrics {
            callCounts[metric.name, default: 0] += 1
            totalDurations[metric.name, default: 0.0] += metric.totalTime
        }
        
        let mostCalled = callCounts.sorted { $0.value > $1.value }
            .prefix(10)
            .map { (function: $0.key, calls: $0.value) }
        
        return MetricsStatistics(
            totalFunctions: metrics.count,
            uniqueFunctions: Set(metrics.map { $0.name }).count,
            totalExecutionTime: totalTime,
            averageExecutionTime: avgTime,
            slowestFunctions: slowest,
            mostCalledFunctions: mostCalled
        )
    }
    
    // Simple heuristic for depth estimation
    private func estimateDepth(for name: String) -> Int {
        if name.contains("main") {
            return 0
        }
        return 1
    }
}

// MARK: - Statistics Model

struct MetricsStatistics {
    let totalFunctions: Int
    let uniqueFunctions: Int
    let totalExecutionTime: Double
    let averageExecutionTime: Double
    let slowestFunctions: [FunctionMetric]
    let mostCalledFunctions: [(function: String, calls: Int)]
}