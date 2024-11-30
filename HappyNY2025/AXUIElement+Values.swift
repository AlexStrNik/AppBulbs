//
//  AXUIElement+Values.swift
//  HappyNY2025
//
//  Created by Aleksandr Strizhnev on 30.11.2024.
//

extension CVTimeStamp {
    var timeInterval: TimeInterval {
        return TimeInterval(videoTime) / TimeInterval(self.videoTimeScale)
    }
}

extension AXUIElement {
    var frame: CGRect {
        var frameValue: CFTypeRef?
        AXUIElementCopyAttributeValue(
            self,
            "AXFrame" as CFString,
            &frameValue
        )
        
        var frame = CGRect.zero
        
        guard let frameValue else {
            return frame
        }
        
        AXValueGetValue(
            frameValue as! AXValue,
            AXValueType.cgRect,
            &frame
        )
        
        return frame
    }
    
    var focused: Bool {
        var focusedValue: CFTypeRef?
        AXUIElementCopyAttributeValue(
            self,
            kAXFocusedAttribute as CFString,
            &focusedValue
        )
        let focused = focusedValue as? Bool
        
        return focused ?? false
    }
    
    var windowId: CGWindowID {
        var windowId: CGWindowID = 0
        _AXUIElementGetWindow(self, &windowId)
        
        return windowId
    }
    
    var windowRole: Bool {
        var windowRole: CFTypeRef?
        AXUIElementCopyAttributeValue(
            self,
            kAXRoleAttribute as CFString,
            &windowRole
        )
        
        guard let windowRole else {
            return false
        }
        
        let role = windowRole as! CFString

        return role == kAXWindowRole as CFString
    }
}
