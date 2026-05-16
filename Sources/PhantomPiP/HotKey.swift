import AppKit
import Carbon.HIToolbox

// Carbon virtual key codes for the keys we bind.
enum Key {
    static let p = 0x23     // ANSI P
    static let c = 0x08     // ANSI C
    static let r = 0x0F     // ANSI R
    static let u = 0x20     // ANSI U
    static let y = 0x10     // ANSI Y
    static let b = 0x0B     // ANSI B
    static let up = 0x7E    // Up arrow
    static let down = 0x7D  // Down arrow
}

// Carbon modifier bit masks (stable, documented values).
enum Mod {
    static let cmd = 1 << 8       // 256
    static let option = 1 << 11   // 2048
    static let control = 1 << 12  // 4096
    static let all = cmd | option | control
}

/// Registers system-wide hot keys via Carbon. Carbon hot keys do not require
/// Accessibility / Input Monitoring permission, unlike NSEvent global monitors,
/// so the app works on first launch with zero prompts.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []
    private var nextID: UInt32 = 1
    private var installed = false

    // Four-char signature 'PHPP' to namespace our hot key IDs.
    private let signature: OSType = {
        let bytes: [UInt8] = [0x50, 0x48, 0x50, 0x50]
        return bytes.reduce(OSType(0)) { ($0 << 8) | OSType($1) }
    }()

    func register(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        installHandlerIfNeeded()

        let id = nextID
        nextID += 1
        handlers[id] = handler

        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(UInt32(keyCode),
                                         UInt32(modifiers),
                                         hkID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &ref)
        if status == noErr, let ref {
            refs.append(ref)
        } else {
            NSLog("PhantomPiP: failed to register hot key (OSStatus \(status))")
        }
    }

    fileprivate func dispatch(id: UInt32) {
        handlers[id]?()
    }

    private func installHandlerIfNeeded() {
        guard !installed else { return }
        installed = true

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),
                            phantomHotKeyCallback,
                            1,
                            &spec,
                            nil,
                            nil)
    }
}

// Top-level C-compatible callback (no captures) handed to Carbon.
private func phantomHotKeyCallback(callRef: EventHandlerCallRef?,
                                   event: EventRef?,
                                   userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hkID = EventHotKeyID()
    let err = GetEventParameter(event,
                                EventParamName(kEventParamDirectObject),
                                EventParamType(typeEventHotKeyID),
                                nil,
                                MemoryLayout<EventHotKeyID>.size,
                                nil,
                                &hkID)
    if err == noErr {
        let id = hkID.id
        DispatchQueue.main.async {
            HotKeyCenter.shared.dispatch(id: id)
        }
    }
    return noErr
}
