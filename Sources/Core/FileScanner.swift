// Sources/Core/FileScanner.swift
import Foundation

final class FileScanner {
    private let inputPath: String
    
    init(inputPath: String) {
        self.inputPath = inputPath
    }
    
    func validatePath() -> Bool {
        FileManager.default.fileExists(atPath: inputPath)
    }
    
    func isDirectory() -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: inputPath, isDirectory: &isDir)
        return isDir.boolValue
    }
    
    func discoverSwiftFiles() -> [String] {
        if !isDirectory() {
            return [inputPath]
        }
        
        return findSwiftFiles(in: inputPath)
    }
    
    private func findSwiftFiles(in directory: String) -> [String] {
        var swiftFiles: [String] = []
        
        guard let enumerator = FileManager.default.enumerator(atPath: directory) else {
            return swiftFiles
        }
        
        for case let file as String in enumerator {
            if file.hasSuffix(".swift") && !file.contains("_instrumented.swift") {
                let fullPath = (directory as NSString).appendingPathComponent(file)
                swiftFiles.append(fullPath)
            }
        }
        
        return swiftFiles.sorted()
    }
    
    func getRelativePath(_ filePath: String) -> String {
        filePath.replacingOccurrences(of: inputPath + "/", with: "")
    }
}