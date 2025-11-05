// Sources/CLI/main.swift
import Foundation
import Core
import Reporting

// Parse command-line arguments
let arguments = CommandLine.arguments

// Show help if no arguments
guard arguments.count >= 2 else {
    print("""
    Usage: async-latency-instrumenter <path> [options]
    
    Arguments:
      <path>              Path to Swift file, directory, or package
    
    Options:
      --json              Export results as JSON
      --csv               Export results as CSV
      --flamegraph        Export results as Speedscope flamegraph
      -o, --output <path> Output file path (defaults to stdout)
      --help              Show this help message
    
    Examples:
      async-latency-instrumenter MyFile.swift
      async-latency-instrumenter MyApp/
      async-latency-instrumenter . --json -o results.json
      async-latency-instrumenter . --csv -o profile.csv
      async-latency-instrumenter . --flamegraph -o profile.json
    """)
    exit(1)
}

// Parse arguments
let inputPath = arguments[1]
var exportFormat: ExportFormat?
var outputPath: String?

enum ExportFormat {
    case json
    case csv
    case flamegraph
}

var i = 2
while i < arguments.count {
    let arg = arguments[i]
    
    switch arg {
    case "--json":
        exportFormat = .json
        i += 1
        
    case "--csv":
        exportFormat = .csv
        i += 1
        
    case "--flamegraph":
        exportFormat = .flamegraph
        i += 1
        
    case "-o", "--output":
        if i + 1 < arguments.count {
            outputPath = arguments[i + 1]
            i += 2
        } else {
            print("Error: --output requires a path argument")
            exit(1)
        }
        
    case "--help":
        print("""
        async-latency-instrumenter - Profile Swift async/await performance
        
        Usage: async-latency-instrumenter <path> [options]
        
        Arguments:
          <path>              Path to Swift file, directory, or package
        
        Options:
          --json              Export results as JSON
          --csv               Export results as CSV
          --flamegraph        Export results as Speedscope flamegraph format
          -o, --output <path> Output file path (defaults to stdout)
          --help              Show this help message
        
        Examples:
          # Profile and show console output
          async-latency-instrumenter MyApp/
          
          # Export to JSON file
          async-latency-instrumenter MyApp/ --json -o results.json
          
          # Export to CSV and print to stdout
          async-latency-instrumenter MyApp/ --csv
          
          # Export flamegraph for speedscope.app
          async-latency-instrumenter MyApp/ --flamegraph -o profile.json
        """)
        exit(0)
        
    default:
        print("Warning: Unknown option '\(arg)' (ignored)")
        i += 1
    }
}

// Create reporter and instrumenter
let reporter = ConsoleReporter()
let instrumenter = Instrumenter(
    inputPath: inputPath,
    reporter: reporter,
    instrumentAwaitPoints: false
)

// Run the instrumentation
let results = await instrumenter.run()

// Export if requested
if let format = exportFormat, let results = results {
    do {
        switch format {
        case .json:
            let exporter = JSONExporter()
            try exporter.export(results: results, to: outputPath)
            
            if let path = outputPath {
                print("\n✅ JSON exported to: \(path)")
            } else {
                print("\n--- JSON OUTPUT ---")
            }
            
        case .csv:
            let exporter = CSVExporter()
            try exporter.export(results: results, to: outputPath)
            
            if let path = outputPath {
                print("\n✅ CSV exported to: \(path)")
            } else {
                print("\n--- CSV OUTPUT ---")
            }
            
        case .flamegraph:
            let exporter = FlameGraphExporter()
            try exporter.export(results: results, to: outputPath)
            
            if let path = outputPath {
                print("\n✅ Flamegraph exported to: \(path)")
                print("   Open at: https://speedscope.app")
            } else {
                print("\n--- FLAMEGRAPH OUTPUT (Speedscope format) ---")
            }
        }
    } catch {
        print("\n❌ Failed to export: \(error)")
        exit(1)
    }
}