//
//  HappyNYApp.swift
//  HappyNY2025
//
//  Created by Aleksandr Strizhnev on 30.11.2024.
//

import SwiftUI

struct DecoratedApplication {
    let observer: AXObserver
}

class DecoratedWindow {
    let windowId: CGWindowID
    let decoration: DecorationWindow
    
    init(windowId: CGWindowID, decoration: DecorationWindow) {
        self.windowId = windowId
        self.decoration = decoration
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

func orderDecorations() {
    let options = CGWindowListOption(
        arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly, .optionOnScreenAboveWindow
    )
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as NSArray? as? [[CFString: AnyObject]] else {
        return
    }
    
    for decoration in AppDelegate.windowDecorations {
        decoration.value.decoration.orderOut(nil)
    }
    
    var topDecoration = Int.max
    for (index, window) in windowList.enumerated() {
        guard let windowId = window[kCGWindowNumber] as? CGWindowID else {
            continue
        }
        
        guard let decoration = AppDelegate.windowDecorations[windowId] else {
            continue
        }
        
        decoration.decoration.order(.above, relativeTo: Int(windowId))
        
        if index < topDecoration {
            topDecoration = index
            decoration.decoration.level = .floating
        } else {
            decoration.decoration.level = .normal
        }
    }
}

func decorateWindow(
    observer: AXObserver,
    window: AXUIElement
) {
    guard window.windowRole else {
        return
    }
    
    guard window.frame != CGRect.zero, window.frame.width > 100 else {
        return
    }
    
    let decorationWindow = DecorationWindow(
        rect: window.frame
    )
    decorationWindow.contentView = NSHostingView(rootView: DecorationView())
    
    let decoration = DecoratedWindow(
        windowId: window.windowId,
        decoration: decorationWindow
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
        
        guard frame != CGRect.zero else {
            return
        }
        
        AppDelegate.windowDecorations[windowId]?.decoration.setFrameOrigin(frame.flipped.origin)
        AppDelegate.windowDecorations[windowId]?.decoration.setContentSize(
            frame.size
        )
    } else if notification.windowCreated {
        guard let element, let observer else {
            return
        }

        decorateWindow(observer: observer, window: element)
    } else if notification.elementDestroyed {
        guard let refcon else {
            return
        }
        
        let windowId = Unmanaged<DecoratedWindow>.fromOpaque(refcon).takeUnretainedValue().windowId
        
        AppDelegate.windowDecorations[windowId]?.decoration.close()
        AppDelegate.windowDecorations.removeValue(forKey: windowId)
    }
    
    orderDecorations()
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    fileprivate static var observedApplications: [Int32 : DecoratedApplication] = [:]
    fileprivate static var windowDecorations: [CGWindowID: DecoratedWindow] = [:]
    
    fileprivate var applicationsObserver: NSKeyValueObservation?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            return
        }

        checkPermission()
        
        applicationsObserver = NSWorkspace.shared.observe(\.runningApplications, options: [.initial]) {(model, change) in
            for application in NSWorkspace.shared.runningApplications {
                guard application.activationPolicy == .regular else {
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
            }
        }
        
        orderDecorations()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        for decoration in AppDelegate.windowDecorations {
            decoration.value.decoration.close()
        }
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
        
        let refcon = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())
        
        AXObserverAddNotification(
            observer,
            applicationElement,
            kAXWindowMovedNotification as CFString,
            refcon
        )
        AXObserverAddNotification(
            observer,
            applicationElement,
            kAXWindowResizedNotification as CFString,
            refcon
        )
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
                window: window
            )
        }
        
        AppDelegate.observedApplications[applicationId] = DecoratedApplication(
            observer: observer
        )
    }
}
