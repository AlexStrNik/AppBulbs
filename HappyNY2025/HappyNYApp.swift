//
//  HappyNYApp.swift
//  HappyNY2025
//
//  Created by Aleksandr Strizhnev on 30.11.2024.
//

import SwiftUI

func getWindows() -> [WindowUniforms]? {
    let options = CGWindowListOption(
        arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly, .optionOnScreenAboveWindow
    )
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as NSArray? as? [[CFString: AnyObject]] else {
        return []
    }

    var decorations: [WindowUniforms] = []
    var decorationRect = CGRect.zero
    
    guard windowList.count > 0 else {
        return []
    }
    
    if windowList[0][kCGWindowOwnerName] as! String == "Screenshot" {
        return nil
    }
    
    for window in windowList {
        guard let boundsDict = window[kCGWindowBounds], let windowLayer = window[kCGWindowLayer] as? Int else {
            continue
        }
        if window[kCGWindowOwnerName] as! String == "HappyNY2025", let rect = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary) {
            decorationRect = rect
            continue
        }
        if windowLayer != 0 {
            continue
        }
        
        guard let rect = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary) else {
            continue
        }
        
        let fixedRect = rect.offsetBy(dx: -decorationRect.minX, dy: -decorationRect.minY)
        decorations.insert(
            WindowUniforms(
                position: SIMD2(Float(fixedRect.minX), Float(fixedRect.minY)),
                size: SIMD2(Float(fixedRect.width), Float(fixedRect.height))
            ),
            at: 0
        )
    }
    
    return decorations
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var shieldingWindow: MetalDecorationWindow? = nil
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            return
        }
        
        shieldingWindow = MetalDecorationWindow(
            rect: NSScreen.screens.first!.frame
        )
        shieldingWindow?.orderFrontRegardless()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        shieldingWindow?.close()
    }
}
