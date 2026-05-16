import Cocoa

// Entry point. A plain SPM executable with no app bundle, so we configure
// NSApplication by hand. `.regular` gives a Dock icon and a standard app
// menu; the always-visible status-bar item is the control surface while
// another app (your editor) is focused.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
