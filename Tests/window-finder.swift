#!/usr/bin/env swift
// pyokotifyウィンドウの中心座標を出力するヘルパー
// 見つからない場合は "NOT_FOUND" を出力

import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
for w in windows {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    if owner == "pyokotify" {
        if let bounds = w[kCGWindowBounds as String] as? [String: CGFloat] {
            let x = bounds["X"] ?? 0
            let y = bounds["Y"] ?? 0
            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0
            let cx = Int(x + width / 2)
            let cy = Int(y + height / 2)
            print("\(cx),\(cy)")
            exit(0)
        }
    }
}
print("NOT_FOUND")
