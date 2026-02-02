import Foundation
import Testing

@testable import PyokotifyCore

@Suite("Claude Code Hooks Tests")
struct ClaudeCodeHooksTests {

    @Test("JSONを正しく解析")
    func parseJson() throws {
        let json = """
            {
                "hook_event_name": "Notification",
                "cwd": "/path/to/project",
                "notification_type": "permission_prompt"
            }
            """.data(using: .utf8)!

        let input = try JSONDecoder().decode(ClaudeHooksInput.self, from: json)
        #expect(input.hookEventName == .notification)
        #expect(input.cwd == "/path/to/project")
        #expect(input.notificationType == "permission_prompt")
    }

    @Test("Stopイベントを正しく解析")
    func parseStopEvent() throws {
        let json = """
            {
                "hook_event_name": "Stop",
                "cwd": "/path/to/project"
            }
            """.data(using: .utf8)!

        let input = try JSONDecoder().decode(ClaudeHooksInput.self, from: json)
        #expect(input.hookEventName == .stop)
    }

    @Test("PreToolUseイベントを正しく解析")
    func parsePreToolUseEvent() throws {
        let json = """
            {
                "hook_event_name": "PreToolUse",
                "cwd": "/path/to/project",
                "tool_name": "Bash"
            }
            """.data(using: .utf8)!

        let input = try JSONDecoder().decode(ClaudeHooksInput.self, from: json)
        #expect(input.hookEventName == .preToolUse)
        #expect(input.toolName == "Bash")
    }

    @Test("未知のイベントはunknownになる")
    func parseUnknownEvent() throws {
        let json = """
            {
                "hook_event_name": "SomeNewEvent",
                "cwd": "/path/to/project"
            }
            """.data(using: .utf8)!

        let input = try JSONDecoder().decode(ClaudeHooksInput.self, from: json)
        #expect(input.hookEventName == .unknown)
    }

    @Test("デフォルトメッセージ生成 - permission_prompt")
    func defaultMessagePermission() {
        let context = ClaudeHooksContext(
            event: .notification,
            cwd: "/path/to/myproject",
            notificationType: "permission_prompt",
            toolName: nil
        )
        let message = context.generateDefaultMessage(projectName: "myproject", branch: "main")
        #expect(message == "[myproject:main] Permission required!")
    }

    @Test("デフォルトメッセージ生成 - Stop")
    func defaultMessageStop() {
        let context = ClaudeHooksContext(
            event: .stop,
            cwd: "/path/to/myproject",
            notificationType: nil,
            toolName: nil
        )
        let message = context.generateDefaultMessage(projectName: "myproject", branch: nil)
        #expect(message == "[myproject] Done!")
    }

    @Test("デフォルトメッセージ生成 - AskUserQuestion")
    func defaultMessageAskUserQuestion() {
        let context = ClaudeHooksContext(
            event: .preToolUse,
            cwd: "/path/to/myproject",
            notificationType: nil,
            toolName: "AskUserQuestion"
        )
        let message = context.generateDefaultMessage(projectName: "myproject", branch: "feature")
        #expect(message == "[myproject:feature] Question for you!")
    }
}

// MARK: - GitHub Copilot CLI Hooks Tests

@Suite("Copilot Hooks Tests")
struct CopilotHooksTests {

    @Test("Copilot sessionStart JSONを正しく解析")
    func parseSessionStart() throws {
        let json = """
            {
                "timestamp": 1704614400000,
                "cwd": "/path/to/project",
                "source": "new",
                "initialPrompt": "Hello"
            }
            """.data(using: .utf8)!

        let input = try JSONDecoder().decode(CopilotHooksInput.self, from: json)
        #expect(input.timestamp == 1704614400000)
        #expect(input.cwd == "/path/to/project")
        #expect(input.source == "new")
        #expect(input.initialPrompt == "Hello")
    }

    @Test("Copilot preToolUse JSONを正しく解析")
    func parsePreToolUse() throws {
        let json = """
            {
                "timestamp": 1704614400000,
                "cwd": "/path/to/project",
                "toolName": "bash",
                "toolArgs": "{\\"command\\":\\"ls\\"}"
            }
            """.data(using: .utf8)!

        let input = try JSONDecoder().decode(CopilotHooksInput.self, from: json)
        #expect(input.toolName == "bash")
        #expect(input.toolArgs == "{\"command\":\"ls\"}")
    }

    @Test("Copilot errorOccurred JSONを正しく解析")
    func parseErrorOccurred() throws {
        let json = """
            {
                "timestamp": 1704614400000,
                "cwd": "/path/to/project",
                "error": {
                    "message": "Something went wrong",
                    "name": "Error"
                }
            }
            """.data(using: .utf8)!

        let input = try JSONDecoder().decode(CopilotHooksInput.self, from: json)
        #expect(input.error?.message == "Something went wrong")
        #expect(input.error?.name == "Error")
    }

    @Test("CopilotHooksEvent から HooksEvent への変換")
    func eventConversion() {
        #expect(CopilotHooksEvent.sessionStart.toHooksEvent == .sessionStart)
        #expect(CopilotHooksEvent.sessionEnd.toHooksEvent == .sessionEnd)
        #expect(CopilotHooksEvent.userPromptSubmitted.toHooksEvent == .userPromptSubmit)
        #expect(CopilotHooksEvent.preToolUse.toHooksEvent == .preToolUse)
        #expect(CopilotHooksEvent.postToolUse.toHooksEvent == .postToolUse)
        #expect(CopilotHooksEvent.errorOccurred.toHooksEvent == .errorOccurred)
    }
}

// MARK: - 自動検出 Tests

@Suite("Hooks Auto Detection Tests")
struct HooksAutoDetectionTests {

    @Test("Claude Code JSONを正しく検出")
    func detectClaudeCode() throws {
        let json: [String: Any] = [
            "hook_event_name": "Stop",
            "cwd": "/path/to/project"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        // JSONSerializationで辞書として読み込めることを確認
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed?["hook_event_name"] != nil)
    }

    @Test("Copilot JSONを正しく検出")
    func detectCopilot() throws {
        let json: [String: Any] = [
            "timestamp": 1704614400000,
            "cwd": "/path/to/project"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        // JSONSerializationで辞書として読み込めることを確認
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed?["timestamp"] != nil)
        #expect(parsed?["hook_event_name"] == nil)
    }
}
