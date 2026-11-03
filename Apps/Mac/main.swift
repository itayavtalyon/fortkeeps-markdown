import AppKit

ScrollEnvironment.app = .live
let app = NSApplication.shared
let delegate = ScrollAppDelegate()
delegate.bookmarks = .standard
app.delegate = delegate
app.run()
