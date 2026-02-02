import Foundation

/// テンプレート展開用のコンテキスト
public struct TemplateContext {
    public let directoryName: String?
    public let branch: String?
    public let cwd: String?
    public let eventName: String?
    public let toolName: String?

    public init(
        cwd: String? = nil,
        branch: String? = nil,
        eventName: String? = nil,
        toolName: String? = nil
    ) {
        self.cwd = cwd
        self.directoryName = cwd.map { ($0 as NSString).lastPathComponent }
        self.branch = branch
        self.eventName = eventName
        self.toolName = toolName
    }
}

/// メッセージテンプレートの変数展開
public enum TemplateExpander {

    /// テンプレート変数を展開
    /// - Parameters:
    ///   - template: 展開前のテンプレート文字列
    ///   - context: 展開に使用するコンテキスト
    /// - Returns: 変数が展開された文字列
    public static func expand(_ template: String, with context: TemplateContext) -> String {
        let variables: [String: String?] = [
            "$dir": context.directoryName,
            "$branch": context.branch,
            "$cwd": context.cwd,
            "$event": context.eventName,
            "$tool": context.toolName,
        ]

        return variables.reduce(template) { result, pair in
            result.replacingOccurrences(of: pair.key, with: pair.value ?? "")
        }
    }
}
