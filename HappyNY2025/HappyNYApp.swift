//
//  HappyNYApp.swift
//  HappyNY2025
//
//  Created by Aleksandr Strizhnev on 30.11.2024.
//

import SwiftUI
import Combine

class DecoratedApplication {
    let applicationId: Int32
    let observer: AXObserver
    
    init(applicationId: Int32, observer: AXObserver) {
        self.applicationId = applicationId
        self.observer = observer
    }
}

class DecoratedWindow {
    let windowId: CGWindowID
    let applicationId: Int32
    
    var frame: CGRect {
        didSet {
            size.x = Float(frame.width)
            size.y = Float(frame.height)
            position.x = Float(frame.minX)
            position.y = Float(frame.minY)
        }
    }
    
    private(set) var size: SIMD2<Float> = .zero
    private(set) var position: SIMD2<Float> = .zero
    
    var order: Int
    
    init(windowId: CGWindowID, applicationId: Int32, frame: CGRect) {
        self.windowId = windowId
        self.applicationId = applicationId
        self.frame = frame
        self.order = -1
    }
}

extension CFString {
    var windowMoved: Bool {
        self == kAXWindowMovedNotification as CFString
    }
    
    var windowResized: Bool {
        self == kAXWindowResizedNotification as CFString
    }
    
    var windowCreated: Bool {
        self == kAXWindowCreatedNotification as CFString
    }
    
    var elementDestroyed: Bool {
        self == kAXUIElementDestroyedNotification as CFString
    }
}

func alignDecorations() {
    let options = CGWindowListOption(
        arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly, .optionOnScreenAboveWindow
    )
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as NSArray? as? [[CFString: AnyObject]] else {
        return
    }

    for decoration in AppDelegate.windowDecorations {
        decoration.value.order = -1
    }
    
    var topDecoration = 0
    var decorationRect = CGRect.zero
    for window in windowList {
        guard let windowId = window[kCGWindowNumber] as? CGWindowID, let boundsDict = window[kCGWindowBounds] else {
            continue
        }
        if window[kCGWindowOwnerName] as! String == "HappyNY2025", let rect = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary) {
            decorationRect = rect
        }
        
        guard let decoration = AppDelegate.windowDecorations[windowId] else {
            continue
        }
        
        guard let rect = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary) else {
            continue
        }
        
        decoration.frame = rect.offsetBy(dx: -decorationRect.minX, dy: -decorationRect.minY)
        decoration.order = topDecoration
        topDecoration += 1
    }
}

func decorateWindow(
    observer: AXObserver,
    applicationId: Int32,
    window: AXUIElement
) {
    guard window.windowRole else {
        return
    }
    
    let decoration = DecoratedWindow(
        windowId: window.windowId,
        applicationId: applicationId,
        frame: window.frame
    )
    AppDelegate.windowDecorations[window.windowId] = decoration
    
    let refcon = UnsafeMutableRawPointer(Unmanaged.passRetained(decoration).toOpaque())
    
    AXObserverAddNotification(
        observer,
        window,
        kAXUIElementDestroyedNotification as CFString,
        refcon
    )
}

func applicationListener(
    observer: AXObserver?,
    element: AXUIElement?,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    if notification.windowMoved || notification.windowResized {
        guard let frame = element?.frame, let windowId = element?.windowId else {
            return
        }
        
        AppDelegate.windowDecorations[windowId]?.frame = frame
    } else if notification.windowCreated {
        guard let element, let observer, let refcon else {
            return
        }
        
        let application = Unmanaged<DecoratedApplication>.fromOpaque(refcon).takeUnretainedValue()

        decorateWindow(
            observer: observer,
            applicationId: application.applicationId,
            window: element
        )
    } else if notification.elementDestroyed {
        guard let refcon else {
            return
        }
        
        let windowId = Unmanaged<DecoratedWindow>.fromOpaque(refcon).takeUnretainedValue().windowId
        
        AppDelegate.windowDecorations.removeValue(forKey: windowId)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    fileprivate static var observedApplications: [Int32 : DecoratedApplication] = [:]
    static var windowDecorations: [CGWindowID: DecoratedWindow] = [:]
        
    fileprivate static var shieldingWindow: MetalDecorationWindow? = nil
    
    fileprivate var applicationsObserver: NSKeyValueObservation?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            return
        }
        
        AppDelegate.shieldingWindow = MetalDecorationWindow(
            rect: NSScreen.screens.first!.frame
        )
        AppDelegate.shieldingWindow?.orderFrontRegardless()
        
        checkPermission()
        
        applicationsObserver = NSWorkspace.shared.observe(\.runningApplications, options: [.initial]) {(model, change) in
            for application in NSWorkspace.shared.runningApplications {
                guard application.activationPolicy == .regular else {
                    continue
                }
                
                guard application.bundleIdentifier != "xyz.alexstrnik.HappyNY2025" else {
                    continue
                }
                
                if AppDelegate.observedApplications[application.processIdentifier] == nil {
                    self.observeApplication(with: application.processIdentifier)
                }
            }
            
            let runningIdentifiers = NSWorkspace.shared.runningApplications.map {
                $0.processIdentifier
            }
            let observedIdentifiers = AppDelegate.observedApplications.keys
            let deadIdentifiers = observedIdentifiers.filter {
                !runningIdentifiers.contains($0)
            }
            
            for identifier in deadIdentifiers {
                AppDelegate.observedApplications.removeValue(forKey: identifier)
                let deadWindows = AppDelegate.windowDecorations.values.filter {
                    $0.applicationId == identifier
                }
                for window in deadWindows {
                    AppDelegate.windowDecorations.removeValue(forKey: window.windowId)
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        AppDelegate.observedApplications = [:]
        AppDelegate.windowDecorations = [:]
    }
    
    func checkPermission() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true
        ]
        AXIsProcessTrustedWithOptions(options)
    }
    
    func observeApplication(with applicationId: Int32) {
        let applicationElement = AXUIElementCreateApplication(applicationId)

        var observer: AXObserver? = nil
        
        AXObserverCreate(
            applicationId,
            applicationListener,
            &observer
        )
        
        guard let observer else {
            return
        }
        
        let decoratedApplication = DecoratedApplication(
            applicationId: applicationId,
            observer: observer
        )
        
        let refcon = UnsafeMutableRawPointer(Unmanaged.passRetained(decoratedApplication).toOpaque())
        
        AXObserverAddNotification(
            observer,
            applicationElement,
            kAXMainWindowChangedNotification as CFString,
            refcon
        )
        AXObserverAddNotification(
            observer,
            applicationElement,
            kAXWindowMiniaturizedNotification as CFString,
            refcon
        )
        AXObserverAddNotification(
            observer,
            applicationElement,
            kAXWindowDeminiaturizedNotification as CFString,
            refcon
        )
        AXObserverAddNotification(
            observer,
            applicationElement,
            kAXWindowCreatedNotification as CFString,
            refcon
        )
        AXObserverAddNotification(
            observer,
            applicationElement,
            kAXFocusedWindowChangedNotification as CFString,
            refcon
        )
        AXObserverAddNotification(
            observer,
            applicationElement,
            kAXApplicationActivatedNotification as CFString,
            refcon
        )
        AXObserverAddNotification(
            observer,
            applicationElement,
            kAXApplicationDeactivatedNotification as CFString,
            refcon
        )
        AXObserverAddNotification(
            observer,
            applicationElement,
            kAXApplicationShownNotification as CFString,
            refcon
        )
        AXObserverAddNotification(
            observer,
            applicationElement,
            kAXApplicationHiddenNotification as CFString,
            refcon
        )
        
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        );

        var windows: CFArray?
        AXUIElementCopyAttributeValues(
            applicationElement,
            kAXWindowsAttribute as CFString,
            0,
            CFIndex.max,
            &windows
        )
        
        guard let windows = windows as? [AXUIElement] else {
            return
        }
        
        for window in windows {
            decorateWindow(
                observer: observer,
                applicationId: applicationId,
                window: window
            )
        }
        
        AppDelegate.observedApplications[applicationId] = decoratedApplication
    }
}
