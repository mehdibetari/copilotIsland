import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let maxRows = 6

    private let store = SessionStore()
    private let server = HookServer()
    private var panels: [CGDirectDisplayID: NSPanel] = [:]
    private var statusItem: NSStatusItem!
    private var cancellable: AnyCancellable?
    private var hoverTimer: Timer?
    private var metrics: [CGDirectDisplayID: IslandMetrics] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()

        server.onEvent = { [weak self] event in
            guard !event.name.isEmpty else { return }
            self?.store.handle(event)
        }
        do { try server.start() } catch {
            let alert = NSAlert()
            alert.messageText = "Impossible d'écouter sur 127.0.0.1:\(HookServer.port)"
            alert.informativeText = "\(error.localizedDescription)\nUne autre instance est peut-être déjà lancée."
            alert.runModal()
            NSApp.terminate(nil)
        }

        cancellable = store.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.updateLayout() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateLayout() }
        }
        updateLayout()

        // Polling the cursor is more reliable than onHover for a panel that resizes and touches the screen's top edge.
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let mouse = NSEvent.mouseLocation
                let inside = self.panels.contains { id, panel in
                    guard panel.isVisible, let m = self.metrics[id] else { return false }
                    return Self.islandRect(m, in: panel.frame, expanded: self.store.hovering).insetBy(dx: 0, dy: -2).contains(mouse)
                }
                if inside != self.store.hovering { self.store.hovering = inside }
            }
        }
    }

    // Visible island rect (top-centered in the panel) used for hover detection.
    private static func islandRect(_ m: IslandMetrics, in frame: NSRect, expanded: Bool) -> NSRect {
        let size = expanded ? m.expanded : m.collapsed
        return NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
    }

    private func makePanel(metrics: IslandMetrics) -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: IslandView(store: store, metrics: metrics))
        return panel
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "Copilot Island")
        let menu = NSMenu()
        menu.addItem(withTitle: "Quitter Copilot Island", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    static let earWidth: CGFloat = 24

    static func notchWidth(of screen: NSScreen) -> CGFloat {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return 0 }
        return screen.frame.width - left.width - right.width
    }

    private func updateLayout() {
        let screens = NSScreen.screens.compactMap { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID).map { ($0, screen) }
        }
        let active = Set(screens.map(\.0))
        for (id, panel) in panels where !active.contains(id) || store.sessions.isEmpty {
            panel.orderOut(nil)
            if !active.contains(id) { panels[id] = nil }
        }
        guard !store.sessions.isEmpty else { return }

        let rows = min(store.sessions.count, Self.maxRows)
        for (id, screen) in screens {
            let notch = screen.safeAreaInsets.top
            let m = IslandMetrics(
                collapsed: NSSize(width: notch > 0 ? Self.notchWidth(of: screen) + 2 * Self.earWidth : 200, height: notch > 0 ? notch : 26),
                expanded: NSSize(width: 460, height: CGFloat(22 + rows * 56) + notch),
                notch: notch)
            metrics[id] = m
            let panel = panels[id] ?? makePanel(metrics: m)
            panels[id] = panel
            (panel.contentView as? NSHostingView<IslandView>)?.rootView = IslandView(store: store, metrics: m)
            let slack = IslandMetrics.slack
            let size = NSSize(width: m.expanded.width + 2 * slack, height: m.expanded.height + slack)
            let frame = NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                               width: size.width, height: size.height)
            if panel.frame != frame { panel.setFrame(frame, display: true, animate: false) }
            // The oversized transparent panel must not swallow clicks meant for the menu bar while collapsed.
            panel.ignoresMouseEvents = !store.expanded
            panel.orderFrontRegardless()
        }
    }
}
