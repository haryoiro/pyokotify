import Foundation

/// 通知レベル
public enum NotificationLevel: String, Codable {
    case info
    case success
    case warning
    case error
}

/// デーモンに送信する通知メッセージ
public struct NotificationMessage: Codable {
    public let message: String?
    public let level: NotificationLevel
    public let sound: String?
    public let duration: TimeInterval?
    public let cwd: String?
    public let callerApp: String?
    public let hooksJson: String?  // Claude Code / Copilot hooks JSON

    public init(
        message: String? = nil,
        level: NotificationLevel = .info,
        sound: String? = nil,
        duration: TimeInterval? = nil,
        cwd: String? = nil,
        callerApp: String? = nil,
        hooksJson: String? = nil
    ) {
        self.message = message
        self.level = level
        self.sound = sound
        self.duration = duration
        self.cwd = cwd
        self.callerApp = callerApp
        self.hooksJson = hooksJson
    }
}

/// デーモンからの応答
public struct DaemonResponse: Codable {
    public let success: Bool
    public let error: String?

    public init(success: Bool, error: String? = nil) {
        self.success = success
        self.error = error
    }
}

/// デーモンのソケットパス
public enum DaemonPaths {
    public static var socketPath: String {
        let tmpDir = FileManager.default.temporaryDirectory.path
        return "\(tmpDir)/pyokotify-daemon.sock"
    }

    public static var pidFile: String {
        let tmpDir = FileManager.default.temporaryDirectory.path
        return "\(tmpDir)/pyokotify-daemon.pid"
    }
}
