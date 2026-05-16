import Cocoa

// Entry point. A plain SPM executable with no app bundle, so we configure
// NSApplication by hand. `.regular` gives a Dock icon and a standard app
// menu; the always-visible status-bar item is the control surface while
// another app (your editor) is focused.
// Utility mode: `PhantomPiP --export-icon [path]` writes the app icon as a
// PNG and exits (handy for building a real .icns if you bundle a .app).
if let i = CommandLine.arguments.firstIndex(of: "--export-icon") {
    let path = CommandLine.arguments.count > i + 1
        ? CommandLine.arguments[i + 1]
        : "PhantomPiP-icon.png"
    let ok = AppIcon.export(to: path)
    FileHandle.standardError.write(Data(
        ((ok ? "wrote " : "failed to write ") + path + "\n").utf8))
    exit(ok ? 0 : 1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
