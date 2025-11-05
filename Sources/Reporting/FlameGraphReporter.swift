// Sources/Reporting/FlameGraphExporter.swift
import Foundation
import Models

public final class FlameGraphExporter {
    
    public init() {}
    
    /// Export results in Speedscope format (https://speedscope.app)
    public func export(results: InstrumentationResults, to outputPath: String?) throws {
        let speedscopeData = buildSpeedscopeFormat(from: results)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(speedscopeData)
        
        if let path = outputPath {
            try data.write(to: URL(fileURLWithPath: path))
        } else {
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        }
    }
    
    private func buildSpeedscopeFormat(from results: InstrumentationResults) -> SpeedscopeFile {
        // Group metrics by thread (we'll simulate a single profile for now)
        let profile = createProfile(from: results.executionMetrics)
        
        return SpeedscopeFile(
            schema: "https://www.speedscope.app/file-format-schema.json",
            activeProfileIndex: 0,
            exporter: "AsyncLatencyInstrumenter v1.0",
            name: "Async Latency Profile",
            shared: SpeedscopeShared(frames: profile.frames),
            profiles: [profile.profile]
        )
    }
    
    private func createProfile(from metrics: [FunctionMetric]) -> (frames: [SpeedscopeFrame], profile: SpeedscopeProfile) {
        var frames: [SpeedscopeFrame] = []
        var events: [SpeedscopeEvent] = []
        
        // Create frames (unique function names)
        var frameMap: [String: Int] = [:]
        for metric in metrics {
            if frameMap[metric.name] == nil {
                frameMap[metric.name] = frames.count
                frames.append(SpeedscopeFrame(name: metric.name))
            }
        }
        
        // Create events (simulated timeline)
        var currentTime: Double = 0.0
        
        for metric in metrics.sorted(by: { $0.totalTime > $1.totalTime }) {
            guard let frameIndex = frameMap[metric.name] else { continue }
            
            // Open event
            events.append(SpeedscopeEvent(
                type: "O",
                at: currentTime,
                frame: frameIndex
            ))
            
            // Close event
            currentTime += metric.totalTime
            events.append(SpeedscopeEvent(
                type: "C",
                at: currentTime,
                frame: frameIndex
            ))
        }
        
        let profile = SpeedscopeProfile(
            type: "evented",
            name: "Async Functions",
            unit: "seconds",
            startValue: 0.0,
            endValue: currentTime,
            events: events
        )
        
        return (frames, profile)
    }
}

// MARK: - Speedscope Format Models

struct SpeedscopeFile: Codable {
    let schema: String
    let activeProfileIndex: Int
    let exporter: String
    let name: String
    let shared: SpeedscopeShared
    let profiles: [SpeedscopeProfile]
    
    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case activeProfileIndex
        case exporter
        case name
        case shared
        case profiles
    }
}

struct SpeedscopeShared: Codable {
    let frames: [SpeedscopeFrame]
}

struct SpeedscopeFrame: Codable {
    let name: String
}

struct SpeedscopeProfile: Codable {
    let type: String
    let name: String
    let unit: String
    let startValue: Double
    let endValue: Double
    let events: [SpeedscopeEvent]
}

struct SpeedscopeEvent: Codable {
    let type: String  // "O" for open, "C" for close
    let at: Double    // Timestamp in seconds
    let frame: Int    // Frame index
}