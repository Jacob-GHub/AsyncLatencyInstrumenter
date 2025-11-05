// Sources/Analysis/AsyncAnalyzer.swift
import SwiftSyntax
import SwiftParser
import Models

public final class AsyncAnalyzer {
    public init() {}
    
    public func analyze(sourceFile: SourceFileSyntax) -> AnalysisResult {
        var asyncFunctions: [AsyncFunctionInfo] = []
        var hasMainAttribute = false
        
        for statement in sourceFile.statements {
            // Top-level functions
            if let funcDecl = statement.item.as(FunctionDeclSyntax.self) {
                if let info = analyzeFunction(funcDecl, context: nil) {
                    asyncFunctions.append(info)
                }
            }
            
            // Structs
            else if let structDecl = statement.item.as(StructDeclSyntax.self) {
                hasMainAttribute = hasMainAttribute || hasMainAttr(structDecl.attributes)
                asyncFunctions.append(contentsOf: analyzeMemberBlock(
                    structDecl.memberBlock,
                    context: structDecl.name.text
                ))
            }
            
            // Classes
            else if let classDecl = statement.item.as(ClassDeclSyntax.self) {
                asyncFunctions.append(contentsOf: analyzeMemberBlock(
                    classDecl.memberBlock,
                    context: classDecl.name.text
                ))
            }
            
            // Enums
            else if let enumDecl = statement.item.as(EnumDeclSyntax.self) {
                asyncFunctions.append(contentsOf: analyzeMemberBlock(
                    enumDecl.memberBlock,
                    context: enumDecl.name.text
                ))
            }
            
            // Extensions
            else if let extDecl = statement.item.as(ExtensionDeclSyntax.self) {
                let typeName = extDecl.extendedType.description.trimmingCharacters(in: .whitespaces)
                asyncFunctions.append(contentsOf: analyzeMemberBlock(
                    extDecl.memberBlock,
                    context: typeName
                ))
            }
        }
        
        return AnalysisResult(
            asyncFunctions: asyncFunctions,
            hasMainAttribute: hasMainAttribute
        )
    }
    
    private func analyzeMemberBlock(_ block: MemberBlockSyntax, context: String?) -> [AsyncFunctionInfo] {
        var functions: [AsyncFunctionInfo] = []
        
        for member in block.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self),
               let info = analyzeFunction(funcDecl, context: context) {
                functions.append(info)
            }
        }
        
        return functions
    }
    
    private func analyzeFunction(_ funcDecl: FunctionDeclSyntax, context: String?) -> AsyncFunctionInfo? {
        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
            return nil
        }
        
        let name = funcDecl.name.text
        let fullName = context != nil ? "\(context!).\(name)" : name
        let awaitCount = countAwaits(in: funcDecl.body)
        
        return AsyncFunctionInfo(
            name: name,
            fullName: fullName,
            awaitCount: awaitCount,
            location: SourceLocation(
                line: funcDecl.position.utf8Offset,
                column: 0
            )
        )
    }
    
    private func countAwaits(in body: CodeBlockSyntax?) -> Int {
        guard let body = body else { return 0 }
        
        class AwaitCounter: SyntaxVisitor {
            var count = 0
            
            override func visit(_ node: AwaitExprSyntax) -> SyntaxVisitorContinueKind {
                count += 1
                return .visitChildren
            }
        }
        
        let counter = AwaitCounter(viewMode: .sourceAccurate)
        counter.walk(body)
        
        return counter.count
    }
    
    private func hasMainAttr(_ attributes: AttributeListSyntax) -> Bool {
        attributes.contains { attr in
            if case .attribute(let attrSyntax) = attr,
               attrSyntax.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "main" {
                return true
            }
            return false
        }
    }
}

public struct AnalysisResult {
    public let asyncFunctions: [AsyncFunctionInfo]
    public let hasMainAttribute: Bool
    
    public init(asyncFunctions: [AsyncFunctionInfo], hasMainAttribute: Bool) {
        self.asyncFunctions = asyncFunctions
        self.hasMainAttribute = hasMainAttribute
    }
}