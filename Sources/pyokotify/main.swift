import AppKit
import PyokotifyCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = PyokotifyAppDelegate()
app.delegate = delegate
app.run()
