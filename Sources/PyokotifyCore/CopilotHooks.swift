import Foundation

// MARK: - GitHub Copilot CLI Hooks

/// GitHub Copilot CLI hooks のイベント種別
public enum CopilotHooksEvent: String, CaseIterable {
    case sessionStart
    case sessionEnd
    case userPromptSubmitted
    case preToolUse
    case postToolUse
    case errorOccurred
    case unknown

    /// 共通イベント種別に変換
    public var toHooksEvent: HooksEvent {
        switch self {
        case .sessionStart: return .sessionStart
        case .sessionEnd: return .sessionEnd
        case .userPromptSubmitted: return .userPromptSubmit
        case .preToolUse: return .preToolUse
        case .postToolUse: return .postToolUse
        case .errorOccurred: return .errorOccurred
        case .unknown: return .unknown
        }
    }

    /// 日本語表示名
    public var displayName: String {
        toHooksEvent.displayName
    }
}

/// GitHub Copilot CLI hooks の入力JSON
public struct CopilotHooksInput: Codable {
    public let timestamp: Int64?
    public let cwd: String?
    public let source: String?           // sessionStart: "new", "resume", "startup"
    public let initialPrompt: String?    // sessionStart
    public let prompt: String?           // userPromptSubmitted
    public let toolName: String?         // preToolUse, postToolUse
    public let toolArgs: String?         // preToolUse, postToolUse (JSON string)
    public let toolResult: AnyCodable?   // postToolUse
    public let error: CopilotError?      // errorOccurred

    public struct CopilotError: Codable {
        public let message: String?
        public let name: String?
        public let stack: String?
    }
}

// MARK: - 統一 Hooks Context

/// 統一されたHooksコンテキスト（Claude Code / GitHub Copilot CLI 両対応）
public struct HooksContext {
    public let source: HooksSource
    public let event: HooksEvent
    public let cwd: String?
    public let toolName: String?
    public let toolInput: ToolInput?
    public let error: String?
    public let message: String?
    public let userPrompt: String?

    // Claude Code専用フィールド
    public let claudeContext: ClaudeHooksContext?

    /// Claude Code の ClaudeHooksContext から生成
    public init(from claudeContext: ClaudeHooksContext) {
        self.source = .claudeCode
        self.event = claudeContext.event.toHooksEvent
        self.cwd = claudeContext.cwd
        self.toolName = claudeContext.toolName
        self.toolInput = claudeContext.toolInput
        self.error = claudeContext.error
        self.message = claudeContext.message
        self.userPrompt = claudeContext.userPrompt
        self.claudeContext = claudeContext
    }

    /// GitHub Copilot CLI の CopilotHooksInput から生成
    public init(from copilotInput: CopilotHooksInput, event: CopilotHooksEvent) {
        self.source = .copilot
        self.event = event.toHooksEvent
        self.cwd = copilotInput.cwd
        self.toolName = copilotInput.toolName
        self.toolInput = copilotInput.toolArgs.flatMap { HooksContext.parseToolArgs($0) }
        self.error = copilotInput.error?.message
        self.message = nil
        self.userPrompt = copilotInput.prompt ?? copilotInput.initialPrompt
        self.claudeContext = nil
    }

    /// toolArgs JSON文字列をToolInputに変換
    private static func parseToolArgs(_ jsonString: String) -> ToolInput? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ToolInput.self, from: data)
    }

    /// 標準入力からJSONを読み取り、自動検出して解析
    public static func readFromStdin() -> HooksContext? {
        guard isatty(FileHandle.standardInput.fileDescriptor) == 0 else {
            return nil
        }

        let inputData = FileHandle.standardInput.readDataToEndOfFile()
        guard !inputData.isEmpty else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] else {
            Log.hooks.error("標準入力のJSONパースに失敗しました (入力サイズ: \(inputData.count) bytes)")
            return nil
        }

        let detectedSource = detectSource(from: json)

        switch detectedSource {
        case .claudeCode:
            guard let claudeContext = ClaudeHooksContext.parse(from: inputData) else {
                return nil
            }
            return HooksContext(from: claudeContext)

        case .copilot:
            guard let (copilotInput, event) = parseCopilotInput(from: inputData, json: json) else {
                return nil
            }
            return HooksContext(from: copilotInput, event: event)
        }
    }

    /// JSONからソースを自動検出
    private static func detectSource(from json: [String: Any]) -> HooksSource {
        if json["hook_event_name"] != nil { return .claudeCode }
        if json["timestamp"] != nil { return .copilot }
        return .claudeCode
    }

    /// GitHub Copilot CLIの入力を解析
    private static func parseCopilotInput(from data: Data, json: [String: Any]) -> (CopilotHooksInput, CopilotHooksEvent)? {
        guard let input = (try? JSONDecoder().decode(CopilotHooksInput.self, from: data)) else {
            Log.hooks.error("GitHub Copilot CLI JSON のデコードに失敗しました")
            return nil
        }

        let event: CopilotHooksEvent
        if json["error"] != nil {
            event = .errorOccurred
        } else if json["toolResult"] != nil {
            event = .postToolUse
        } else if json["toolName"] != nil {
            event = .preToolUse
        } else if json["prompt"] != nil {
            event = .userPromptSubmitted
        } else if json["source"] != nil || json["initialPrompt"] != nil {
            event = .sessionStart
        } else {
            event = .sessionEnd
        }

        return (input, event)
    }

    /// イベントに応じたデフォルトメッセージを生成
    public func generateDefaultMessage(projectName: String?, branch: String?) -> String {
        if let claudeContext = claudeContext {
            return claudeContext.generateDefaultMessage(projectName: projectName, branch: branch)
        }

        let projectInfo = formatProjectInfo(projectName: projectName, branch: branch)

        switch event {
        case .sessionStart:     return "\(projectInfo) Session started!"
        case .sessionEnd:       return "\(projectInfo) Session ended"
        case .userPromptSubmit: return "\(projectInfo) Processing prompt..."
        case .preToolUse:       return "\(projectInfo) Running: \(toolName ?? "tool")"
        case .postToolUse:      return "\(projectInfo) Completed: \(toolName ?? "tool")"
        case .errorOccurred:    return "\(projectInfo) Error: \(error ?? "unknown")"
        default:                return "\(projectInfo) Event"
        }
    }

    private func formatProjectInfo(projectName: String?, branch: String?) -> String {
        guard let name = projectName else { return "" }
        if let branch = branch, !branch.isEmpty {
            return "[\(name):\(branch)]"
        }
        return "[\(name)]"
    }
}

// MARK: - ClaudeHooksContext 拡張

extension ClaudeHooksContext {
    /// Dataから解析（HooksContext用）
    static func parse(from data: Data) -> ClaudeHooksContext? {
        do {
            let decoder = JSONDecoder()
            let input = try decoder.decode(ClaudeHooksInput.self, from: data)
            return ClaudeHooksContext(from: input)
        } catch {
            Log.hooks.error("ClaudeHooksInput のデコードに失敗: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
