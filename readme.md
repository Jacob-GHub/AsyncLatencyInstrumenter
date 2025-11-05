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

## ✨ What's New: Swift Package Support

The profiler now works with **complete Swift applications**, not just individual files!

### Supported Project Types

| Type | Support | How It Works |
|------|---------|--------------|
| **Swift Package (SPM)** | ✅ Full Support | Automatically detected, built, and profiled |
| **Directory of .swift files** | ✅ Full Support | Individual file instrumentation |
| **Single .swift file** | ✅ Full Support | Direct compilation and profiling |
| **Xcode Projects** | 🚧 Coming Soon | Planned for future release |

### Example: Profile a Real Swift App

```bash
# Clone any Swift package
git clone https://github.com/vapor/vapor.git
cd vapor

# Profile it!
swift run async-latency-instrumenter . --json -o vapor-profile.json
```

## 📊 What You Get

### Current Features (Working Now)

✅ **Swift Package Profiling** - Profile entire applications with dependencies
✅ **Basic Timing** - Total execution time for each async function
```
[Latency] fetchUser: 0.106556s
[Latency] processData: 0.212079s
[Latency] main: 0.451752s
```

✅ **Function Discovery** - Automatic detection of all async functions
```
Total files processed: 15
Files with async functions: 8
Total async functions found: 42
```

✅ **Structured Metrics** - JSON output for programmatic analysis
✅ **Nested Call Tracking** - See which functions call which
✅ **Auto-compilation** - Builds and runs instrumented code automatically
✅ **Console Output** - Colored, formatted reports

### Advanced Features (With --await-points flag)

🔧 **Await Point Timing** - See individual suspension points
```
    ⏸️  await #1: 206.438ms
    ⏸️  await #2: 55.023ms
```

🔧 **Compute vs Suspend Breakdown** - Understand where time goes
```
[📊 Profile] fetchUser
  ├─ Total: 0.106027s
  ├─ Compute: 0.000342s (0.3%)
  ├─ Suspended: 0.105685s (99.7%)
  └─ Await points: 1
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

### Key Technical Details

**SwiftSyntax Integration:**
- Uses Apple's SwiftSyntax library for robust AST manipulation
- Preserves source formatting and comments
- Type-safe syntax tree transformations

**Metrics Collection:**
- Thread-safe collection using `NSLock`
- Structured JSON output for reliable parsing
- Special marker in output: `__ASYNC_PROFILER_METRICS__:/tmp/async_profile_12345.json`
- Automatic cleanup via `atexit` handler

**Timing Mechanism:**
- Uses `ContinuousClock` for high-precision timing
- Measures both seconds and attoseconds (10^-18 seconds)
- Captures wall-clock time including suspension points

**Package Building:**
- Preserves all dependencies from `Package.swift`
- Uses `swift build` for proper module resolution
- Locates executables in `.build/release/`
- Cleans up temporary build artifacts

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

## 🎯 Use Cases

### 1. Find Slow Async Operations in Your App
```bash
cd ~/Projects/MyApp
swift run async-latency-instrumenter . > profile.txt
grep -E "\d+\.\d+s" profile.txt | sort -rn
```

### 2. Profile API Server Performance
```bash
git clone https://github.com/vapor/vapor-example.git
cd vapor-example
async-latency-instrumenter . --json -o vapor-perf.json
```

### 3. Optimize Concurrent Code
```bash
# Before optimization
async-latency-instrumenter . --json -o before.json

# Make your changes...

# After optimization
async-latency-instrumenter . --json -o after.json

# Compare the results
diff <(jq '.executionMetrics' before.json) <(jq '.executionMetrics' after.json)
```

### 4. CI/CD Performance Monitoring
```yaml
# .github/workflows/profile.yml
- name: Profile Async Performance
  run: |
    swift run async-latency-instrumenter . --json -o metrics.json
    # Upload metrics.json to your monitoring dashboard
```

### 5. Identify Async/Await Antipatterns
```bash
# Find functions with many rapid calls (possible improper usage)
async-latency-instrumenter . --json -o profile.json
jq '.executionMetrics | group_by(.name) | map({name: .[0].name, calls: length}) | sort_by(.calls) | reverse | .[0:10]' profile.json
```

## 🧪 Testing Your Profiler

### Create a Test Swift Package

```bash
mkdir TestApp && cd TestApp
swift package init --type executable
```

### Add Async Code

Edit `Sources/TestApp/main.swift`:

```swift
import Foundation

@main
struct TestApp {
    static func main() async {
        print("Starting profiler test...")
        await runAsyncOperations()
        print("Test complete!")
    }
}

func runAsyncOperations() async {
    let users = await fetchUsers()
    print("Found \(users.count) users")
    
    await processUsers(users)
}

func fetchUsers() async -> [String] {
    await Task.sleep(for: .milliseconds(100))
    return ["Alice", "Bob", "Charlie"]
}

func processUsers(_ users: [String]) async {
    for user in users {
        await processUser(user)
    }
}

func processUser(_ name: String) async {
    await Task.sleep(for: .milliseconds(50))
    print("Processed: \(name)")
}
```

### Profile It

```bash
swift run async-latency-instrumenter .
```

### Expected Output

```
📦 Detected Swift Package at: /Users/you/TestApp
📋 Copying package to temporary location...
🔧 Instrumenting Swift files...
✅ Instrumented 1 file(s)
🏗️  Building instrumented package...

======================================================================
🚀 RUNNING INSTRUMENTED PACKAGE
======================================================================

Starting profiler test...
Found 3 users
Processed: Alice
Processed: Bob
Processed: Charlie
Test complete!

✅ Parsed 5 metrics from structured output

======================================================================
📊 EXECUTION STATISTICS
======================================================================
Total function calls: 5
Unique functions: 3
Total execution time: 0.250000s
Average execution time: 0.050000s

🐌 Slowest Functions:
  1. fetchUsers: 0.100000s
  2. processUser: 0.050000s (3 calls)

🔥 Most Called Functions:
  1. processUser: 3 calls
  2. fetchUsers: 1 call
  3. processUsers: 1 call
======================================================================
```

## 🐛 Troubleshooting

### "File is already instrumented"
```bash
# Clean up instrumented files
find . -name "*_instrumented.swift" -delete
# Run again on original files
swift run async-latency-instrumenter MyFile.swift
```

### "No async functions found"
- Make sure your functions use `async` keyword
- Check file actually contains async code
- Verify file is being scanned (check instrumentation summary)

### "Package build failed"
**First, verify the original package builds:**
```bash
cd /path/to/package
swift build
```

Common causes:
- Missing dependencies in `Package.swift`
- Compilation errors in original code
- Platform incompatibility (requires macOS 13+)

### "Could not find built executable"
- Ensure package has an executable target (not library-only)
- Check `.build/release/` directory exists
- Verify `Package.swift` has `.executableTarget()`

### Compilation fails
- Ensure original code compiles without errors
- Check for SwiftSyntax version compatibility
- Try `swift build` first to verify environment

## 🔬 Advanced Features

### Understanding Metrics Output

The profiler writes structured JSON to `/tmp/async_profile_<pid>.json`:

```json
[
  {
    "function": "fetchUsers",
    "duration": 0.100234,
    "timestamp": 1699027234.567,
    "line": 42,
    "file": "main.swift",
    "threadID": 123456789
  }
]
```

Fields:
- `function`: Function name
- `duration`: Execution time in seconds
- `timestamp`: Unix timestamp when function completed
- `line`: Approximate line number in source
- `file`: Source file name
- `threadID`: Mach thread ID (useful for concurrency analysis)

### Working with Large Codebases

For projects with many files:
```bash
# Progress indicator automatically shows for 10+ files
async-latency-instrumenter ./LargeProject

# Verbose output for debugging
async-latency-instrumenter ./LargeProject --verbose
```

### Profiling Specific Targets

For multi-target packages, the profiler runs the first executable target. To profile specific targets:

```bash
# Temporarily modify Package.swift to make your target first
# Or use swift run directly on the instrumented package:
cd /tmp/async_profiler_<uuid>
swift run YourSpecificTarget
```

## 🔮 Roadmap

### In Progress
- [x] Swift Package support
- [x] Structured metrics output
- [x] Multi-file instrumentation
- [ ] Enhanced await point instrumentation
- [ ] Compute/suspend time breakdown

### Planned Features
- [ ] Xcode project support
- [ ] Real-time profiling mode
- [ ] Integration with Instruments.app
- [ ] Web-based flamegraph viewer
- [ ] Call stack visualization
- [ ] Memory profiling for async contexts
- [ ] Async/await antipattern detection
- [ ] Performance regression detection
- [ ] Multi-target profiling
- [ ] Remote profiling (SSH/Docker)

## 📄 License

MIT

## 🤝 Contributing

Contributions welcome! Areas of interest:
- Xcode project support
- Better visualization tools
- Additional export formats
- Performance optimizations
- Documentation improvements
- Test coverage

## 🙏 Acknowledgments

Built with:
- [SwiftSyntax](https://github.com/apple/swift-syntax) - Apple's Swift syntax library
- Swift Package Manager - Dependency management and building
- ContinuousClock - High-precision timing

## 📚 Further Reading

- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [SwiftSyntax Guide](https://github.com/apple/swift-syntax)
- [Swift Package Manager](https://swift.org/package-manager/)
- [Profiling Swift Code](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance)# AsyncLatencyInstrumenter
