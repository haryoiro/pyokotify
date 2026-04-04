import AVFoundation
import AppKit

/// サウンド再生ユーティリティ
public class SoundPlayer {
    private var audioPlayer: AVAudioPlayer?

    public init() {}

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
            Log.sound.error("サウンド再生エラー: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    @discardableResult
    public func playSystemSound(named name: String) -> Bool {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.play()
            return true
        }
        return false
    }
}
