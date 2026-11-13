import AppKit

/// Double-clicking a blank area of the window toggles between the current
/// window frame and a screen-filling zoom. We remember the exact previous
/// frame so the second double-click always restores the original size.
enum WindowZoomSupport {
    private static var savedFrames: [ObjectIdentifier: NSRect] = [:]

    static func toggleZoom() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        guard window.styleMask.contains(.resizable), !window.styleMask.contains(.fullScreen) else { return }

        let id = ObjectIdentifier(window)
        if let saved = savedFrames.removeValue(forKey: id) {
            window.setFrame(saved, display: true, animate: true)
        } else {
            savedFrames[id] = window.frame
            let target = window.screen?.visibleFrame ?? window.frame
            window.setFrame(target, display: true, animate: true)
        }
    }
}
