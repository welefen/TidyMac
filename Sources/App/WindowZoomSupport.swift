import AppKit

/// Double-clicking a blank area of the window toggles between the standard
/// window frame and a screen-filling zoom, mirroring the green traffic light.
enum WindowZoomSupport {
    static func toggleZoom() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        guard window.styleMask.contains(.resizable) else { return }
        guard !window.styleMask.contains(.fullScreen) else { return }
        window.zoom(nil)
    }
}
