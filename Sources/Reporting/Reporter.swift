// Sources/Reporting/Reporter.swift
import Foundation
import Models

public protocol Reporter {
    func report(summary: ProjectSummary)
    func reportExecution(message: String)
    func showProgress(current: Int, total: Int)
    func clearProgress()
}
