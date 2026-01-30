import AppKit
import PokkofyCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = PokkofyAppDelegate()
app.delegate = delegate
app.run()
