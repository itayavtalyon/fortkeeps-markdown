import AppKit

ScrollEnvironment.app = .live
let app = NSApplication.shared
let delegate = ScrollAppDelegate()
app.delegate = delegate
app.run()
