import AppKit
import SwiftUI

/// A transparent, click-through panel pinned over the notch. It is as large as the island
/// ever gets; only the part the island currently covers accepts the mouse.
final class IslandWindow: NSPanel {
    static let canvas = NSSize(width: 460, height: 540)

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

/// Lets the first click or tap on the island work without activating Islet first.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Places the island on the notched screen, passes clicks through everywhere else, and
/// works out which slot the pointer is over.
@MainActor
final class IslandController {
    let model: IslandModel
    private let window: IslandWindow
    private var timer: Timer?

    init<Content: View>(model: IslandModel, content: Content) {
        self.model = model
        window = IslandWindow(rootView: content)
        place()
        window.orderFrontRegardless()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.place() }
        }
        // Polling is cheaper and more reliable than tracking areas on a window that is
        // click-through most of the time, and it works while Islet isn't active.
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.track() }
        }
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.model.expansion != nil, !self.islandRect.contains(NSEvent.mouseLocation) else { return }
                self.model.close()
            }
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, let self, self.model.expansion != nil else { return event }
            self.model.close()
            return nil
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
            // No notch: a slim stand-in the height of the menu bar.
            model.notchSize = CGSize(width: 120, height: NSStatusBar.system.thickness)
            model.hasNotch = false
        }
        let size = IslandWindow.canvas
        window.setFrame(NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                               width: size.width, height: size.height), display: true)
    }

    private var islandRect: NSRect {
        let frame = window.frame
        let size = model.drawnSize
        return NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
    }

    private func track() {
        let point = NSEvent.mouseLocation
        let inside = islandRect.contains(point)
        window.ignoresMouseEvents = !inside
        if model.isPointerInside != inside { model.isPointerInside = inside }
        let hovered = inside && model.expansion == nil ? model.slot(atOffset: point.x - window.frame.midX) : nil
        if model.hovered != hovered {
            withAnimation(.snappy(duration: 0.18)) { model.hovered = hovered }
        }
    }
}
