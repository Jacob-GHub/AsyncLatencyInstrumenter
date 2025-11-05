// Sources/Reporting/JSONExporter.swift
import Foundation
import Models

public final class JSONExporter {
    
    public init() {}
    
    /// Export results to JSON file or stdout
    public func export(results: InstrumentationResults, to outputPath: String?) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(results)
        
        if let path = outputPath {
            // Write to file
            try data.write(to: URL(fileURLWithPath: path))
        } else {
            // Write to stdout
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        }
    }
}