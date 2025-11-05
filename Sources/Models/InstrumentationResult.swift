// Sources/Models/InstrumentationResult.swift
import Foundation

/// Complete results from profiling run
public struct InstrumentationResults: Codable {
    public let summary: ProjectSummary
    public let executionMetrics: [FunctionMetric]
    public let timestamp: Date
    
    public init(summary: ProjectSummary, executionMetrics: [FunctionMetric], timestamp: Date) {
        self.summary = summary
        self.executionMetrics = executionMetrics
        self.timestamp = timestamp
    }
}

/// Summary of files analyzed
public struct ProjectSummary: Codable {
    public let totalFiles: Int
    public let filesWithAsync: Int
    public let totalAsyncFunctions: Int
    public let fileDetails: [FileDetails]
    
    public init(totalFiles: Int, filesWithAsync: Int, totalAsyncFunctions: Int, fileDetails: [FileDetails]) {
        self.totalFiles = totalFiles
        self.filesWithAsync = filesWithAsync
        self.totalAsyncFunctions = totalAsyncFunctions
        self.fileDetails = fileDetails
    }
}

/// Details for a single file
public struct FileDetails: Codable {
    public let path: String
    public let asyncFunctionCount: Int
    public let functions: [String]
    
    public init(path: String, asyncFunctionCount: Int, functions: [String]) {
        self.path = path
        self.asyncFunctionCount = asyncFunctionCount
        self.functions = functions
    }
}

/// Metrics for a single function execution
public struct FunctionMetric: Codable {
    public let name: String
    public let totalTime: Double
    public let computeTime: Double?
    public let suspendTime: Double?
    public let awaitCount: Int?
    public let depth: Int
    
    public init(name: String, totalTime: Double, computeTime: Double? = nil, suspendTime: Double? = nil, awaitCount: Int? = nil, depth: Int = 0) {
        self.name = name
        self.totalTime = totalTime
        self.computeTime = computeTime
        self.suspendTime = suspendTime
        self.awaitCount = awaitCount
        self.depth = depth
    }
}

/// Information about an async function found during analysis
/// NOTE: Keep existing structure - don't change this!
public struct AsyncFunctionInfo {
    public let name: String
    public let fullName: String
    public let awaitCount: Int
    public let location: SourceLocation
    
    public init(name: String, fullName: String, awaitCount: Int, location: SourceLocation) {
        self.name = name
        self.fullName = fullName
        self.awaitCount = awaitCount
        self.location = location
    }
}

/// Source location information
public struct SourceLocation {
    public let line: Int
    public let column: Int
    
    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

/// Result from analyzing a single file
public struct InstrumentationResult {
    public let originalPath: String
    public let instrumentedPath: String
    public let asyncFunctions: [AsyncFunctionInfo]
    public let hasMainAttribute: Bool
    
    public init(originalPath: String, instrumentedPath: String, asyncFunctions: [AsyncFunctionInfo], hasMainAttribute: Bool) {
        self.originalPath = originalPath
        self.instrumentedPath = instrumentedPath
        self.asyncFunctions = asyncFunctions
        self.hasMainAttribute = hasMainAttribute
    }
}