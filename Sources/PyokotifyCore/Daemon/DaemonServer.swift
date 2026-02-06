import Foundation

/// Unix socketで通知を受け付けるサーバー
public class DaemonServer {
    private let socketPath: String
    private var serverSocket: Int32 = -1
    private var isRunning = false
    private let queue = DispatchQueue(label: "pyokotify.daemon.server")

    public var onNotification: ((NotificationMessage) -> Void)?

    public init(socketPath: String = DaemonPaths.socketPath) {
        self.socketPath = socketPath
    }

    deinit {
        stop()
    }

    /// サーバーを起動
    public func start() throws {
        // 既存のソケットファイルを削除
        unlink(socketPath)

        // ソケット作成
        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw DaemonError.socketCreationFailed
        }

        // バインド
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                let pathBuf = UnsafeMutableRawPointer(pathPtr).assumingMemoryBound(to: CChar.self)
                strcpy(pathBuf, ptr)
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverSocket, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            close(serverSocket)
            throw DaemonError.bindFailed
        }

        // リッスン
        guard listen(serverSocket, 5) == 0 else {
            close(serverSocket)
            throw DaemonError.listenFailed
        }

        isRunning = true

        // PIDファイル作成
        try "\(getpid())".write(toFile: DaemonPaths.pidFile, atomically: true, encoding: .utf8)

        // 接続受付ループ
        queue.async { [weak self] in
            self?.acceptLoop()
        }

        debug("Server started at \(socketPath)")
    }

    /// サーバーを停止
    public func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
        unlink(socketPath)
        unlink(DaemonPaths.pidFile)
        debug("Server stopped")
    }

    /// 接続受付ループ
    private func acceptLoop() {
        debug("Accept loop started")
        while isRunning {
            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            debug("Waiting for connection...")
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    accept(serverSocket, sockPtr, &clientAddrLen)
                }
            }

            guard clientSocket >= 0 else {
                if isRunning {
                    debug("Accept failed: \(errno)")
                }
                continue
            }

            debug("Client connected: socket=\(clientSocket)")
            handleClient(clientSocket)
        }
    }

    /// クライアント接続を処理
    private func handleClient(_ clientSocket: Int32) {
        defer { close(clientSocket) }

        debug("Handling client")

        // データ受信
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(clientSocket, &buffer, buffer.count)

        debug("Bytes read: \(bytesRead)")

        guard bytesRead > 0 else {
            sendResponse(to: clientSocket, success: false, error: "No data received")
            return
        }

        let data = Data(bytes: buffer, count: bytesRead)

        // JSONデコード
        do {
            let message = try JSONDecoder().decode(NotificationMessage.self, from: data)
            debug("Received notification: \(message.message)")

            // メインスレッドで通知ハンドラを呼び出し
            DispatchQueue.main.async { [weak self] in
                self?.onNotification?(message)
            }

            sendResponse(to: clientSocket, success: true)
        } catch {
            debug("Failed to decode message: \(error)")
            sendResponse(to: clientSocket, success: false, error: error.localizedDescription)
        }
    }

    /// 応答を送信
    private func sendResponse(to socket: Int32, success: Bool, error: String? = nil) {
        let response = DaemonResponse(success: success, error: error)
        guard let data = try? JSONEncoder().encode(response) else { return }

        _ = data.withUnsafeBytes { ptr in
            write(socket, ptr.baseAddress!, data.count)
        }
    }

    private func debug(_ message: String) {
        if ProcessInfo.processInfo.environment["PYOKOTIFY_DEBUG"] != nil {
            fputs("[pyokotify-daemon] \(message)\n", stderr)
        }
    }
}

/// デーモンエラー
public enum DaemonError: Error, LocalizedError {
    case socketCreationFailed
    case bindFailed
    case listenFailed
    case connectionFailed
    case sendFailed
    case alreadyRunning
    case notRunning

    public var errorDescription: String? {
        switch self {
        case .socketCreationFailed: return "ソケットの作成に失敗しました"
        case .bindFailed: return "ソケットのバインドに失敗しました"
        case .listenFailed: return "リッスンに失敗しました"
        case .connectionFailed: return "接続に失敗しました"
        case .sendFailed: return "送信に失敗しました"
        case .alreadyRunning: return "デーモンは既に起動しています"
        case .notRunning: return "デーモンが起動していません"
        }
    }
}
