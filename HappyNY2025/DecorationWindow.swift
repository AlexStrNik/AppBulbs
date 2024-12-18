//
//  DecorationWindow.swift
//  HappyNY2025
//
//  Created by Aleksandr Strizhnev on 30.11.2024.
//

import Foundation
import MetalKit
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

class MetalDecorationWindow: NSPanel {
    private var renderer: DecorationRenderer?
    
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
        
        self.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenAuxiliary, .canJoinAllSpaces, .canJoinAllApplications]
        self.isOpaque = false
        self.isMovable = false
        self.hasShadow = false
        self.level = .floating
        self.ignoresMouseEvents = true
        self.backgroundColor = .clear
        self.sharingType = .readOnly
        
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        
        self.renderer = DecorationRenderer(metalKitView: mtkView, window: self)
        mtkView.delegate = self.renderer
        
        mtkView.preferredFramesPerSecond = 120
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.drawableSize = mtkView.frame.size
        mtkView.layer?.isOpaque = false
        
        self.contentView = mtkView;
    }
}
