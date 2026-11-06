import CoreGraphics
import Foundation

// Prints the CGWindowID of the frontmost on-screen 清羽 window.
// Usage: windowid [pid] — when a PID is given, only that process is considered.
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}

let targetPID: Int? = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) : nil

for window in raw {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    let ownerPID = window[kCGWindowOwnerPID as String] as? Int ?? 0
    let layer = window[kCGWindowLayer as String] as? Int ?? -1
    let number = window[kCGWindowNumber as String] as? Int ?? 0
    let bounds = window[kCGWindowBounds as String] as? [String: Any]
    let width = bounds?["Width"] as? Double ?? 0
    let height = bounds?["Height"] as? Double ?? 0

    if let targetPID, ownerPID != targetPID { continue }

    if (owner == "清羽" || owner == "Qingyu" || owner.contains("Qingyu")),
       layer == 0, width > 900, height > 600 {
        print(number)
        exit(0)
    }
}

exit(1)
