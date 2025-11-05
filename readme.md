# Async Latency Profiler

A powerful developer tool for profiling Swift async/await performance in **real Swift applications**. Automatically instruments your code to measure execution time, suspension points, and compute vs I/O breakdown.

## 🚀 Quick Start

```bash
# Profile a Swift Package (NEW!)
swift run async-latency-instrumenter /path/to/MySwiftApp

# Profile a single file
swift run async-latency-instrumenter MyFile.swift

# Profile entire directory
swift run async-latency-instrumenter Sources/

# Enable detailed await point analysis
swift run async-latency-instrumenter MyFile.swift --await-points

# Export results
swift run async-latency-instrumenter MyFile.swift --export json --output results.json
swift run async-latency-instrumenter MyFile.swift --export csv --output profile.csv
swift run async-latency-instrumenter MyFile.swift --export flamegraph --output profile.json
```

### Example: Profile a Real Swift App

```bash
# Clone any Swift package
git clone https://github.com/vapor/vapor.git
cd vapor

# Profile it!
swift run async-latency-instrumenter . --json -o vapor-profile.json
```

### Export Formats

**JSON Export** (`--export json`)
```json
{
  "timestamp": "2025-11-04T10:30:00Z",
  "summary": {
    "totalFiles": 1,
    "filesWithAsync": 1,
    "totalAsyncFunctions": 6
  },
  "executionMetrics": [
    {
      "name": "fetchUser",
      "totalTime": 0.106556,
      "depth": 1
    }
  ]
}
```

**CSV Export** (`--export csv`)
```csv
Function,Total Time (s),Compute Time (s),Suspend Time (s),Await Count,Compute %,Suspend %
fetchUser,0.106556,0.000342,0.106214,1,0.32,99.68
processData,0.212079,0.000287,0.211792,1,0.14,99.86
```

**Flamegraph** (`--export flamegraph`)
- Generates Speedscope-compatible JSON
- Open at https://speedscope.app or use Chrome DevTools
- Visualize call hierarchy and time distribution

## 📖 Usage Guide

### Command Line Options

```
USAGE: async-latency-instrumenter <path> [options]

ARGUMENTS:
  <path>                  Path to Swift file, directory, or package

OPTIONS:
  -a, --await-points      Enable detailed await point instrumentation
  -e, --export <format>   Export format: json, csv, flamegraph
  -o, --output <path>     Output file path for export
  --no-color             Disable colored output
  -v, --verbose          Verbose output
  -h, --help             Show help information
```

### Understanding the Output

**For Swift Packages:**

```
📦 Detected Swift Package at: /Users/dev/MySwiftApp
📋 Copying package to temporary location...
🔧 Instrumenting Swift files...
✅ Instrumented 5 file(s)
🏗️  Building instrumented package...

======================================================================
🚀 RUNNING INSTRUMENTED PACKAGE
======================================================================

[Your app output here...]

✅ Parsed 127 metrics from structured output

======================================================================
📊 EXECUTION STATISTICS
======================================================================
Total function calls: 127
Unique functions: 23
Total execution time: 2.456789s
Average execution time: 0.019344s

🐌 Slowest Functions:
  1. fetchUserData: 0.856234s
  2. processImages: 0.421567s
  3. syncDatabase: 0.298456s
  4. validateAuth: 0.156789s
  5. loadConfig: 0.123456s

🔥 Most Called Functions:
  1. logEvent: 45 calls
  2. validateRequest: 23 calls
  3. parseJSON: 18 calls
  4. updateCache: 12 calls
  5. checkPermission: 9 calls
======================================================================
```

**Time Measurements:**
- `fetchUser: 0.106556s` = 106.6 milliseconds total
- `main: 0.451752s` = 451.8 milliseconds total

## 🔧 How It Works

The profiler uses a sophisticated multi-stage process:

### Stage 1: Detection & Analysis
1. **Path Analysis** - Determines if input is a package, directory, or file
2. **Package Detection** - Looks for `Package.swift` to identify SPM packages
3. **File Discovery** - Recursively scans for `.swift` files
4. **AST Parsing** - Uses SwiftSyntax to parse Swift code into syntax trees
5. **Function Detection** - Identifies all `async` functions in the codebase

### Stage 2: Instrumentation

For **Swift Packages**:
1. **Copy Package** - Creates temporary working directory
2. **Preserve Structure** - Copies `Package.swift`, `Sources/`, `Tests/`, and `Package.resolved`
3. **Inject Metrics Collector** - Adds profiling infrastructure to each file
4. **Instrument Functions** - Wraps async functions with timing code
5. **Build Package** - Uses `swift build` to compile the instrumented version

For **Individual Files**:
1. **Parse File** - Creates AST from source code
2. **Inject Metrics** - Adds profiling infrastructure
3. **Instrument Functions** - Wraps async functions with timing code
4. **Compile** - Uses `swiftc` to create executable

### Stage 3: Execution
1. **Run Binary** - Executes the instrumented application
2. **Capture Output** - Collects both console output and metrics data
3. **Metrics Collection** - Profiling data is written to `/tmp/async_profile_<pid>.json`

### Stage 4: Analysis & Reporting
1. **Parse Metrics** - Reads structured JSON metrics file
2. **Aggregate Data** - Calculates statistics, call counts, and timings
3. **Generate Report** - Formats output for console or export
4. **Cleanup** - Removes temporary files and instrumented code

### What Gets Instrumented

Original code:
```swift
func fetchUser() async {
    await Task.sleep(for: .seconds(0.1))
    print("User fetched!")
}
```

After instrumentation:
```swift
// Auto-injected metrics collector (at top of file)
final class __AsyncProfilerMetrics {
    static let shared = __AsyncProfilerMetrics()
    // ... metrics collection code ...
    func record(function: String, duration: Double, line: Int, file: String)
    func flush() // Writes to /tmp/async_profile_<pid>.json
}

func fetchUser() async {
    // Injected timing code
    let __start_fetchUser = ContinuousClock.now
    defer {
        let __end = ContinuousClock.now
        let __duration = __start_fetchUser.duration(to: __end)
        let __seconds = Double(__duration.components.seconds) + 
                        Double(__duration.components.attoseconds) / 1e18
        __AsyncProfilerMetrics.shared.record(
            function: "fetchUser",
            duration: __seconds,
            line: 42,
            file: "main.swift"
        )
    }
    
    // Original code unchanged
    await Task.sleep(for: .seconds(0.1))
    print("User fetched!")
}
```
## 📁 Project Structure

```
AsyncLatencyInstrumenter/
├── Sources/
│   ├── CLI/                        # Command-line interface
│   │   └── main.swift              # Entry point, argument parsing
│   ├── Core/                       # Main instrumentation logic
│   │   ├── Instrumenter.swift      # Orchestrates the profiling process
│   │   ├── PackageInstrumenter.swift  # NEW: Swift Package handling
│   │   ├── Compiler.swift          # Compilation and execution
│   │   ├── FileScanner.swift       # File discovery
│   │   └── MetricsParser.swift     # Parse collected metrics
│   ├── Analysis/                   # Code analysis
│   │   └── AsyncAnalyzer.swift     # Detect async functions
│   ├── Rewriting/                  # AST transformation
│   │   └── AsyncLatencyRewriter.swift  # Inject instrumentation
│   ├── Reporting/                  # Output formatting
│   │   ├── ConsoleReporter.swift   # Terminal output
│   │   ├── JSONExporter.swift      # JSON export
│   │   ├── CSVExporter.swift       # CSV export
│   │   └── FlameGraphExporter.swift # Flamegraph export
│   └── Models/                     # Data structures
│       ├── AsyncFunctionInfo.swift
│       ├── FunctionMetric.swift
│       └── ProjectSummary.swift
├── Tests/
└── Package.swift                   # SPM manifest
```
