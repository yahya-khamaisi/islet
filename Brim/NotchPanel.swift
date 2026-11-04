import AppKit
import SwiftUI

/// A transparent, click-through panel pinned over the notch. It is as large as the open
/// notch ever gets; only the part the notch currently covers accepts the mouse.
final class NotchPanel: NSPanel {
    static let canvas = NSSize(width: Metrics.openWidth + 2 * Metrics.openFlare, height: 460)

    init<Content: View>(rootView: Content) {
        super.init(contentRect: NSRect(origin: .zero, size: Self.canvas),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .init(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        ignoresMouseEvents = true
        contentView = FirstClickHostingView(rootView: rootView)
    }

    override var canBecomeKey: Bool { true }
}

/// Lets the first click on a button work without activating Brim first.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Places the panel on the notched screen and opens or closes the notch as the pointer
/// comes and goes.
@MainActor
final class NotchController {
    let model: NotchModel
    private let panel: NotchPanel
    private var timer: Timer?
    private var hoverSince: Date?
    private var leftSince: Date?

    init<Content: View>(model: NotchModel, content: Content) {
        self.model = model
        panel = NotchPanel(rootView: content)
        place()
        panel.orderFrontRegardless()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.place() }
        }
        // Polling the pointer is cheaper and more reliable than tracking areas on a
        // window that is click-through most of the time.
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.track() }
        }
        // A click anywhere else closes the notch, pinned or not.
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.model.isOpen, !self.drawnRect.contains(NSEvent.mouseLocation) else { return }
                self.model.close()
            }
        }
    }

    /// The screen with a notch, else the one with the menu bar.
    private var screen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens.first
    }

    private func place() {
        guard let screen else { return }
        if screen.safeAreaInsets.top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            model.notchSize = CGSize(width: right.minX - left.maxX, height: screen.safeAreaInsets.top)
            model.hasNotch = true
        } else {
            model.notchSize = CGSize(width: 180, height: NSStatusBar.system.thickness)
            model.hasNotch = false
        }
        let size = NotchPanel.canvas
        panel.setFrame(NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                              width: size.width, height: size.height), display: true)
    }

    /// Where the notch is drawn right now, in screen coordinates.
    private var drawnRect: NSRect {
        let frame = panel.frame
        let size = model.drawnSize
        return NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
    }

    private func track() {
        let point = NSEvent.mouseLocation
        // A few points of slack below the closed notch make it easy to hit.
        let slack: CGFloat = model.isOpen ? 4 : 6
        let inside = drawnRect.insetBy(dx: -slack, dy: -slack).contains(point)
        panel.ignoresMouseEvents = !inside

        if model.isOpen {
            if inside || model.isPinned {
                leftSince = nil
            } else if let since = leftSince {
                if Date.now.timeIntervalSince(since) > 0.35 { model.close(); leftSince = nil }
            } else {
                leftSince = .now
            }
        } else if inside, UserDefaults.standard.bool(forKey: Defaults.openOnHover) {
            if let since = hoverSince {
                if Date.now.timeIntervalSince(since) > 0.12 { model.open(); hoverSince = nil }
            } else {
                hoverSince = .now
            }
        } else {
            hoverSince = nil
        }
    }
}
