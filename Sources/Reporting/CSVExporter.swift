// Sources/Reporting/CSVExporter.swift
import Foundation
import Models

public final class CSVExporter {
    
    public init() {}
    
    /// Export results to CSV file or stdout
    public func export(results: InstrumentationResults, to outputPath: String?) throws {
        let csv = buildCSV(from: results)
        
        if let path = outputPath {
            // Write to file
            try csv.write(toFile: path, atomically: true, encoding: .utf8)
        } else {
            // Write to stdout
            print(csv)
        }
    }
    
    private func buildCSV(from results: InstrumentationResults) -> String {
        var lines: [String] = []
        
        // Header
        lines.append("Function,Total Time (s),Compute Time (s),Suspend Time (s),Await Count,Compute %,Suspend %,Depth")
        
        // Data rows
        for metric in results.executionMetrics.sorted(by: { $0.totalTime > $1.totalTime }) {
            let computeTime = metric.computeTime.map { String(format: "%.6f", $0) } ?? ""
            let suspendTime = metric.suspendTime.map { String(format: "%.6f", $0) } ?? ""
            let awaitCount = metric.awaitCount.map { "\($0)" } ?? ""
            
            let computePercent: String
            let suspendPercent: String
            
            if let compute = metric.computeTime, let suspend = metric.suspendTime {
                let total = compute + suspend
                if total > 0 {
                    computePercent = String(format: "%.2f", (compute / total) * 100)
                    suspendPercent = String(format: "%.2f", (suspend / total) * 100)
                } else {
                    computePercent = ""
                    suspendPercent = ""
                }
            } else {
                computePercent = ""
                suspendPercent = ""
            }
            
            let row = [
                escapeCSV(metric.name),
                String(format: "%.6f", metric.totalTime),
                computeTime,
                suspendTime,
                awaitCount,
                computePercent,
                suspendPercent,
                "\(metric.depth)"
            ].joined(separator: ",")
            
            lines.append(row)
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func escapeCSV(_ field: String) -> String {
        // If field contains comma, quote, or newline, wrap in quotes and escape quotes
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}