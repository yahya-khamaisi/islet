import AppKit
import Carbon.HIToolbox

/// A fixed key combination, with Carbon modifier flags for `RegisterEventHotKey`.
struct Shortcut: Equatable {
    var keyCode: Int
    var carbonModifiers: Int
    var display: String

    static let allow = Shortcut(keyCode: kVK_ANSI_Y, carbonModifiers: cmdKey | controlKey, display: "⌃⌘Y")
    static let deny = Shortcut(keyCode: kVK_ANSI_N, carbonModifiers: cmdKey | controlKey, display: "⌃⌘N")
}

/// Global hotkey via Carbon, the same approach as Driftly. Unregisters when released.
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void
    private let id: UInt32

    /// Each hotkey needs its own `id`; every handler sees every press and passes on the others.
    init(_ shortcut: Shortcut, id: UInt32, action: @escaping () -> Void) {
        self.action = action
        self.id = id
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            let me = Unmanaged<HotKey>.fromOpaque(userData!).takeUnretainedValue()
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            guard pressed.id == me.id else { return OSStatus(eventNotHandledErr) }
            me.action()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        RegisterEventHotKey(UInt32(shortcut.keyCode), UInt32(shortcut.carbonModifiers),
                            EventHotKeyID(signature: OSType(0x4953_4C54), id: id),
                            GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
