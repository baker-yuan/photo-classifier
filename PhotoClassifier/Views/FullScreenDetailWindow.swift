import SwiftUI
import AppKit

// MARK: - Notification Names

extension Notification.Name {
    static let detailKeyEvent = Notification.Name("detailKeyEvent")
    static let detailScrollEvent = Notification.Name("detailScrollEvent")
    static let detailDoubleClick = Notification.Name("detailDoubleClick")
}

// MARK: - Full-Screen Window Manager

final class FullScreenDetailWindow {
    static let shared = FullScreenDetailWindow()
    private var window: NSWindow?
    private var eventMonitor: Any?
    private var scrollMonitor: Any?
    private var clickMonitor: Any?
    private init() {}

    func show(vm: ClassifierViewModel) {
        close()

        guard let screen = NSApp.keyWindow?.screen ?? NSScreen.main else { return }

        let win = _FullScreenPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.setFrame(screen.frame, display: true)
        win.backgroundColor = .black
        win.isOpaque = true
        win.hasShadow = false
        win.level = NSWindow.Level(NSWindow.Level.normal.rawValue + 1)

        let hosting = NSHostingView(
            rootView: PhotoDetailView()
                .environmentObject(vm)
        )
        win.contentView = hosting
        win.makeKeyAndOrderFront(nil)

        NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]

        // Intercept ⌘+number BEFORE the menu system handles it.
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.window?.isKeyWindow == true else { return event }
            if event.modifierFlags.contains(.command),
               let chars = event.charactersIgnoringModifiers, chars.count == 1,
               let num = chars.first?.wholeNumberValue, num >= 1, num <= 9 {
                NotificationCenter.default.post(name: .detailKeyEvent, object: "\(num)")
                return nil // consumed
            }
            return event
        }

        // Scroll wheel → zoom
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard self?.window?.isKeyWindow == true else { return event }
            let delta = event.scrollingDeltaY
            guard abs(delta) > 0.1 else { return event }
            NotificationCenter.default.post(
                name: .detailScrollEvent,
                object: nil,
                userInfo: ["delta": delta, "precise": event.hasPreciseScrollingDeltas]
            )
            return nil
        }

        // Double-click → toggle zoom (only in the central media area)
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let win = self?.window, win.isKeyWindow, event.clickCount == 2 else { return event }
            let loc = event.locationInWindow
            let size = win.frame.size
            // Exclude top 56px (topBar), bottom 100px (bottomBar), sides 80px (nav arrows)
            let inMediaArea = loc.x > 80 && loc.x < size.width - 80
                && loc.y > 100 && loc.y < size.height - 56
            guard inMediaArea else { return event }
            NotificationCenter.default.post(name: .detailDoubleClick, object: nil)
            return event
        }

        self.window = win
    }

    func close() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        window?.orderOut(nil)
        window = nil
        NSApp.presentationOptions = []
    }
}

private class _FullScreenPanel: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        let key: String?
        switch event.keyCode {
        case 123: key = "left"
        case 124: key = "right"
        case 53:  key = "escape"
        case 49:  key = "space"
        case 24:  key = "zoomIn"     // + / =
        case 27:  key = "zoomOut"    // - / _
        case 29:  key = "zoomReset"  // 0
        default:  key = nil
        }
        if let key = key {
            NotificationCenter.default.post(name: .detailKeyEvent, object: key)
        }
    }
}
