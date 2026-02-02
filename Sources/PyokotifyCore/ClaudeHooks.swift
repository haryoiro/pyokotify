import Foundation

// MARK: - イベント種別

/// Claude Code hooks の全イベント種別（12種類）
public enum ClaudeHooksEvent: String, Codable, CaseIterable {
    case sessionStart = "SessionStart"
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
    case permissionRequest = "PermissionRequest"
    case postToolUse = "PostToolUse"
    case postToolUseFailure = "PostToolUseFailure"
    case notification = "Notification"
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"
    case stop = "Stop"
    case preCompact = "PreCompact"
    case sessionEnd = "SessionEnd"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = ClaudeHooksEvent(rawValue: value) ?? .unknown
    }

    /// 日本語表示名
    public var displayName: String {
        switch self {
        case .sessionStart: return "セッション開始"
        case .userPromptSubmit: return "プロンプト送信"
        case .preToolUse: return "ツール実行前"
        case .permissionRequest: return "権限要求"
        case .postToolUse: return "ツール実行後"
        case .postToolUseFailure: return "ツール失敗"
        case .notification: return "通知"
        case .subagentStart: return "サブエージェント開始"
        case .subagentStop: return "サブエージェント終了"
        case .stop: return "完了"
        case .preCompact: return "コンパクション前"
        case .sessionEnd: return "セッション終了"
        case .unknown: return "不明"
        }
    }
}

// MARK: - Notification種別

/// Notification イベントの種別
public enum NotificationType: String, Codable {
    case permissionPrompt = "permission_prompt"
    case idlePrompt = "idle_prompt"
    case authSuccess = "auth_success"
    case elicitationDialog = "elicitation_dialog"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = NotificationType(rawValue: value) ?? .unknown
    }

    public var displayName: String {
        switch self {
        case .permissionPrompt: return "権限確認"
        case .idlePrompt: return "入力待ち"
        case .authSuccess: return "認証成功"
        case .elicitationDialog: return "ダイアログ"
        case .unknown: return "通知"
        }
    }
}

// MARK: - SessionStart種別

/// SessionStart イベントのソース種別
public enum SessionStartSource: String, Codable {
    case startup = "startup"
    case resume = "resume"
    case clear = "clear"
    case compact = "compact"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = SessionStartSource(rawValue: value) ?? .unknown
    }
}

// MARK: - SessionEnd種別

/// SessionEnd イベントの終了理由
public enum SessionEndReason: String, Codable {
    case clear = "clear"
    case logout = "logout"
    case promptInputExit = "prompt_input_exit"
    case bypassPermissionsDisabled = "bypass_permissions_disabled"
    case other = "other"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = SessionEndReason(rawValue: value) ?? .unknown
    }
}

// MARK: - PreCompact種別

/// PreCompact イベントのトリガー種別
public enum PreCompactTrigger: String, Codable {
    case manual = "manual"
    case auto = "auto"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = PreCompactTrigger(rawValue: value) ?? .unknown
    }
}

// MARK: - ツール入力

/// ツール入力の共通構造
public struct ToolInput: Codable {
    // Bash
    public let command: String?
    public let description: String?
    public let timeout: Int?
    public let runInBackground: Bool?

    // Write/Edit/Read
    public let filePath: String?
    public let content: String?
    public let oldString: String?
    public let newString: String?
    public let replaceAll: Bool?
    public let offset: Int?
    public let limit: Int?

    // Glob/Grep
    public let pattern: String?
    public let path: String?
    public let glob: String?
    public let outputMode: String?

    // WebFetch/WebSearch
    public let url: String?
    public let query: String?
    public let prompt: String?

    // Task
    public let subagentType: String?

    enum CodingKeys: String, CodingKey {
        case command, description, timeout
        case runInBackground = "run_in_background"
        case filePath = "file_path"
        case content
        case oldString = "old_string"
        case newString = "new_string"
        case replaceAll = "replace_all"
        case offset, limit
        case pattern, path, glob
        case outputMode = "output_mode"
        case url, query, prompt
        case subagentType = "subagent_type"
    }
}

// MARK: - メイン入力構造体

/// Claude Code hooks の入力JSON（全フィールド対応）
public struct ClaudeHooksInput: Codable {
    // 共通フィールド
    public let hookEventName: ClaudeHooksEvent
    public let sessionId: String?
    public let transcriptPath: String?
    public let cwd: String?
    public let permissionMode: String?

    // Notification
    public let notificationType: String?
    public let message: String?
    public let title: String?

    // Tool events (PreToolUse, PostToolUse, etc.)
    public let toolName: String?
    public let toolInput: ToolInput?
    public let toolResponse: AnyCodable?
    public let toolUseId: String?
    public let error: String?
    public let isInterrupt: Bool?

    // SessionStart
    public let source: String?
    public let model: String?
    public let agentType: String?

    // SessionEnd
    public let reason: String?

    // PreCompact
    public let trigger: String?
    public let customInstructions: String?

    // Subagent events
    public let agentId: String?
    public let agentTranscriptPath: String?

    // Stop
    public let stopHookActive: Bool?

    // UserPromptSubmit
    public let userPrompt: String?

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case sessionId = "session_id"
        case transcriptPath = "transcript_path"
        case cwd
        case permissionMode = "permission_mode"
        case notificationType = "notification_type"
        case message, title
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case toolResponse = "tool_response"
        case toolUseId = "tool_use_id"
        case error
        case isInterrupt = "is_interrupt"
        case source, model
        case agentType = "agent_type"
        case reason, trigger
        case customInstructions = "custom_instructions"
        case agentId = "agent_id"
        case agentTranscriptPath = "agent_transcript_path"
        case stopHookActive = "stop_hook_active"
        case userPrompt = "prompt"
    }
}

// MARK: - AnyCodable（任意JSON対応）

/// 任意のJSON値を扱うためのラッパー
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - 解析コンテキスト

/// Claude Code hooks の解析結果
public struct ClaudeHooksContext {
    public let event: ClaudeHooksEvent
    public let cwd: String?
    public let sessionId: String?

    // Notification
    public let notificationType: NotificationType?
    public let message: String?
    public let title: String?

    // Tool events
    public let toolName: String?
    public let toolInput: ToolInput?
    public let error: String?
    public let isInterrupt: Bool

    // SessionStart
    public let source: SessionStartSource?
    public let model: String?

    // SessionEnd
    public let endReason: SessionEndReason?

    // PreCompact
    public let compactTrigger: PreCompactTrigger?

    // Subagent
    public let agentType: String?
    public let agentId: String?

    // Stop
    public let stopHookActive: Bool

    // UserPromptSubmit
    public let userPrompt: String?

    public init(from input: ClaudeHooksInput) {
        self.event = input.hookEventName
        self.cwd = input.cwd
        self.sessionId = input.sessionId

        self.notificationType = input.notificationType.flatMap { NotificationType(rawValue: $0) }
        self.message = input.message
        self.title = input.title

        self.toolName = input.toolName
        self.toolInput = input.toolInput
        self.error = input.error
        self.isInterrupt = input.isInterrupt ?? false

        self.source = input.source.flatMap { SessionStartSource(rawValue: $0) }
        self.model = input.model

        self.endReason = input.reason.flatMap { SessionEndReason(rawValue: $0) }

        self.compactTrigger = input.trigger.flatMap { PreCompactTrigger(rawValue: $0) }

        self.agentType = input.agentType
        self.agentId = input.agentId

        self.stopHookActive = input.stopHookActive ?? false

        self.userPrompt = input.userPrompt
    }

    /// テスト・直接生成用イニシャライザ
    public init(
        event: ClaudeHooksEvent,
        cwd: String? = nil,
        sessionId: String? = nil,
        notificationType: String? = nil,
        message: String? = nil,
        title: String? = nil,
        toolName: String? = nil,
        toolInput: ToolInput? = nil,
        error: String? = nil,
        isInterrupt: Bool = false,
        source: SessionStartSource? = nil,
        model: String? = nil,
        endReason: SessionEndReason? = nil,
        compactTrigger: PreCompactTrigger? = nil,
        agentType: String? = nil,
        agentId: String? = nil,
        stopHookActive: Bool = false,
        userPrompt: String? = nil
    ) {
        self.event = event
        self.cwd = cwd
        self.sessionId = sessionId
        self.notificationType = notificationType.flatMap { NotificationType(rawValue: $0) }
        self.message = message
        self.title = title
        self.toolName = toolName
        self.toolInput = toolInput
        self.error = error
        self.isInterrupt = isInterrupt
        self.source = source
        self.model = model
        self.endReason = endReason
        self.compactTrigger = compactTrigger
        self.agentType = agentType
        self.agentId = agentId
        self.stopHookActive = stopHookActive
        self.userPrompt = userPrompt
    }

    /// 標準入力からJSONを読み取り解析
    public static func readFromStdin() -> ClaudeHooksContext? {
        guard isatty(FileHandle.standardInput.fileDescriptor) == 0 else {
            return nil
        }

        let inputData = FileHandle.standardInput.readDataToEndOfFile()
        guard !inputData.isEmpty else { return nil }

        do {
            let decoder = JSONDecoder()
            let input = try decoder.decode(ClaudeHooksInput.self, from: inputData)
            return ClaudeHooksContext(from: input)
        } catch {
            return nil
        }
    }

    /// イベントに応じたデフォルトメッセージを生成
    public func generateDefaultMessage(projectName: String?, branch: String?) -> String {
        let projectInfo = formatProjectInfo(projectName: projectName, branch: branch)

        switch event {
        case .sessionStart:
            switch source {
            case .startup: return "\(projectInfo) Session started!"
            case .resume: return "\(projectInfo) Session resumed!"
            case .clear: return "\(projectInfo) Session cleared!"
            case .compact: return "\(projectInfo) Context compacted!"
            default: return "\(projectInfo) Session started!"
            }

        case .userPromptSubmit:
            return "\(projectInfo) Processing prompt..."

        case .preToolUse:
            if toolName == "AskUserQuestion" {
                return "\(projectInfo) Question for you!"
            }
            return "\(projectInfo) Running: \(toolName ?? "tool")"

        case .permissionRequest:
            return "\(projectInfo) Permission needed: \(toolName ?? "action")"

        case .postToolUse:
            return "\(projectInfo) Completed: \(toolName ?? "tool")"

        case .postToolUseFailure:
            if isInterrupt {
                return "\(projectInfo) Interrupted: \(toolName ?? "tool")"
            }
            return "\(projectInfo) Failed: \(toolName ?? "tool")"

        case .notification:
            switch notificationType {
            case .permissionPrompt:
                return "\(projectInfo) Permission required!"
            case .idlePrompt:
                return "\(projectInfo) Waiting for input!"
            case .authSuccess:
                return "\(projectInfo) Authentication successful!"
            case .elicitationDialog:
                return "\(projectInfo) Dialog needed!"
            default:
                return message ?? "\(projectInfo) Notification"
            }

        case .subagentStart:
            return "\(projectInfo) Agent started: \(agentType ?? "agent")"

        case .subagentStop:
            return "\(projectInfo) Agent finished: \(agentType ?? "agent")"

        case .stop:
            if stopHookActive {
                return "\(projectInfo) Continuing..."
            }
            return "\(projectInfo) Done!"

        case .preCompact:
            switch compactTrigger {
            case .manual: return "\(projectInfo) Manual compaction..."
            case .auto: return "\(projectInfo) Auto compaction..."
            default: return "\(projectInfo) Compacting..."
            }

        case .sessionEnd:
            switch endReason {
            case .clear: return "\(projectInfo) Session cleared"
            case .logout: return "\(projectInfo) Logged out"
            case .promptInputExit: return "\(projectInfo) Session ended"
            default: return "\(projectInfo) Session ended"
            }

        case .unknown:
            return "\(projectInfo) Event"
        }
    }

    /// ツール情報の簡潔な説明を生成
    public func getToolDescription() -> String? {
        guard let toolName = toolName else { return nil }

        switch toolName {
        case "Bash":
            return toolInput?.command.map { cmd in
                let short = cmd.count > 50 ? String(cmd.prefix(47)) + "..." : cmd
                return "$ \(short)"
            }
        case "Write", "Edit", "Read":
            return toolInput?.filePath.map { path in
                (path as NSString).lastPathComponent
            }
        case "Glob", "Grep":
            return toolInput?.pattern
        case "WebFetch":
            return toolInput?.url
        case "WebSearch":
            return toolInput?.query
        case "Task":
            return toolInput?.subagentType ?? toolInput?.description
        default:
            return nil
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
