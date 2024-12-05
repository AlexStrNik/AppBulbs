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
    
    let screen = NSScreen.main!

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
        
        if rect.maxX < 0 || rect.minX > screen.frame.width {
            continue
        }
        
        let fixedRect = rect.offsetBy(dx: -decorationRect.minX, dy: -decorationRect.minY)
        decorations.insert(
            WindowUniforms(
                position: SIMD2(Float(fixedRect.minX), Float(fixedRect.minY)),
                size: SIMD2(Float(fixedRect.width), Float(fixedRect.height)),
                fullscreen: rect.width == screen.frame.width ? 1 : 0
            ),
            at: 0
        )
    }
    
    return decorations
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var shieldingWindow: MetalDecorationWindow? = nil
    
    private var statusMenu: NSMenu!
    private var statusBarItem: NSStatusItem!
    
    private var enabled: Bool = true
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            return
        }
        
        enableDecorations()
        
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let statusButton = statusBarItem!.button
        statusButton!.image = NSImage(systemSymbolName: "warninglight.fill", accessibilityDescription: "AppBulbs")
        
        let toggle = NSMenuItem(title: "Toggle", action: #selector(toggle), keyEquivalent: "")
        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        
        statusMenu = NSMenu()
        
        statusMenu!.addItem(toggle)
        statusMenu!.addItem(.separator())
        statusMenu!.addItem(quit)
        
        statusBarItem!.menu = statusMenu!
    }
    
    func enableDecorations() {
        shieldingWindow = MetalDecorationWindow(
            rect: NSScreen.screens.first!.frame
        )
        shieldingWindow?.orderFrontRegardless()
    }
    
    func disableDecorations() {
        shieldingWindow?.close()
    }
    
    @objc func toggle() {
        if enabled {
            disableDecorations()
        } else {
            enableDecorations()
        }
        enabled.toggle()

        statusBarItem!.button!.image = NSImage(
            systemSymbolName: enabled ? "warninglight.fill" : "warninglight",
            accessibilityDescription: "AppBulbs"
        )
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        shieldingWindow?.close()
    }
}
