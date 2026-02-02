import AVFoundation
import AppKit

/// サウンド再生ユーティリティ
public class SoundPlayer {
    private var audioPlayer: AVAudioPlayer?

    public init() {}

    /// 指定された音声ファイルを再生
    /// - Parameter path: 音声ファイルのパス
    /// - Returns: 再生成功時はtrue
    @discardableResult
    public func play(path: String) -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        // まずNSSoundで試す（システムサウンドにも対応）
        if let sound = NSSound(contentsOf: url, byReference: true) {
            sound.play()
            return true
        }

        // NSSoundで失敗した場合はAVAudioPlayerを試す
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            return true
        } catch {
            print("サウンド再生エラー: \(error.localizedDescription)")
            return false
        }
    }

    /// システムサウンド名で再生
    /// - Parameter name: システムサウンド名（例: "Glass", "Ping", "Pop"）
    @discardableResult
    public func playSystemSound(named name: String) -> Bool {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.play()
            return true
        }
        return false
    }
}
