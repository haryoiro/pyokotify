#!/usr/bin/env swift
// pyokotifyウィンドウをクリックするヘルパー
// Usage: click-at <x> <y>
//
// 方法1: pyokotifyプロセスのPIDを指定してCGEventを直接送信
// 方法2: AXUIElement で kAXPressAction を試行

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3,
    let x = Double(CommandLine.arguments[1]),
    let y = Double(CommandLine.arguments[2])
else {
    fputs("Usage: click-at <x> <y>\n", stderr)
    exit(1)
}

let point = CGPoint(x: x, y: y)

// pyokotify のプロセスを探す
guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == "pyokotify" })
else {
    fputs("pyokotify process not found\n", stderr)
    exit(1)
}

let pid = app.processIdentifier

// CGEvent をプロセス指定で送信
func postMouseEvent(_ type: CGEventType) {
    guard let event = CGEvent(
        mouseEventSource: nil,
        mouseType: type,
        mouseCursorPosition: point,
        mouseButton: .left
    ) else { return }
    event.postToPid(pid)
}

postMouseEvent(.mouseMoved)
usleep(50_000)
postMouseEvent(.leftMouseDown)
usleep(50_000)
postMouseEvent(.leftMouseUp)

fputs("clicked pyokotify (pid=\(pid)) at \(Int(x)),\(Int(y))\n", stderr)
