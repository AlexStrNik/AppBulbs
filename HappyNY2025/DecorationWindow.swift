//
//  DecorationWindow.swift
//  HappyNY2025
//
//  Created by Aleksandr Strizhnev on 30.11.2024.
//

import Foundation
import AppKit

extension CGRect {
    var flipped: CGRect {
        let screens = NSScreen.screens
        guard let screenWithWindow = (screens.first {
            NSPointInRect(self.origin, $0.frame)
        }) else {
            return self
        }
        
        return CGRect(
            x: self.minX,
            y: screenWithWindow.frame.height - self.origin.y - self.height,
            width: self.width,
            height: self.height
        )
    }
}

class DecorationWindow: NSPanel {
    public convenience init(rect: CGRect) {
        self.init(
            contentRect: rect.flipped,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        self.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenAuxiliary]
        self.isOpaque = false
        self.isMovable = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.backgroundColor = .clear
    }
}
