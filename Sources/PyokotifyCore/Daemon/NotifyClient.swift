import Foundation

/// デーモンに通知を送信するクライアント
public class NotifyClient {
    private let socketPath: String

    public init(socketPath: String = DaemonPaths.socketPath) {
        self.socketPath = socketPath
    }

    /// デーモンが起動しているか確認
    public func isDaemonRunning() -> Bool {
        guard FileManager.default.fileExists(atPath: socketPath) else {
            return false
        }

        // 実際に接続できるか確認
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                let pathBuf = UnsafeMutableRawPointer(pathPtr).assumingMemoryBound(to: CChar.self)
                strcpy(pathBuf, ptr)
            }
        }

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        return result == 0
    }

    /// 通知を送信
    public func send(_ message: NotificationMessage) throws -> DaemonResponse {
        // ソケットファイルの存在だけチェック（接続テストはしない）
        guard FileManager.default.fileExists(atPath: socketPath) else {
            throw DaemonError.notRunning
        }

        // ソケット作成
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else {
            throw DaemonError.socketCreationFailed
        }
        defer { close(sock) }

        // 接続
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                let pathBuf = UnsafeMutableRawPointer(pathPtr).assumingMemoryBound(to: CChar.self)
                strcpy(pathBuf, ptr)
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard connectResult == 0 else {
            throw DaemonError.notRunning  // 接続できない場合はデーモンが起動していない
        }

        // メッセージ送信
        let data = try JSONEncoder().encode(message)
        let writeResult = data.withUnsafeBytes { ptr in
            write(sock, ptr.baseAddress!, data.count)
        }

        guard writeResult > 0 else {
            throw DaemonError.sendFailed
        }

        // 応答受信
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(sock, &buffer, buffer.count)

        guard bytesRead > 0 else {
            return DaemonResponse(success: true)
        }

        let responseData = Data(bytes: buffer, count: bytesRead)
        return try JSONDecoder().decode(DaemonResponse.self, from: responseData)
    }

    /// 簡易送信（メッセージのみ）
    public func send(_ text: String, level: NotificationLevel = .info) throws -> DaemonResponse {
        let message = NotificationMessage(message: text, level: level)
        return try send(message)
    }
}
