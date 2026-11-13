import AppKit
import SwiftUI

@main
struct KeyHeatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environmentObject(delegate.state)
        } label: {
            Image(systemName: "keyboard")
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    private lazy var dashboard = DashboardWindowController(state: state)
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)   // light mode only
        state.showDashboard = { [weak self] in self?.dashboard.show() }
        // Keep App Nap from throttling the tap thread and periodic flushes.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Counting key presses")
        installMainMenu()

        let defaults = UserDefaults.standard
        let firstLaunch = !defaults.bool(forKey: "launchedBefore")
        defaults.set(true, forKey: "launchedBefore")
        if state.tracking == .noPermission && !AppState.tapDisabledByEnvironment {
            KeyTap.requestPermission()
        }
        if firstLaunch || state.tracking == .noPermission || AppState.tapDisabledByEnvironment {
            dashboard.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.store.flushSync()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        dashboard.show()
        return true
    }

    /// LSUIElement apps have no menu bar, but a main menu is still what makes
    /// ⌘Q / ⌘W / ⌘C work while the dashboard window is key.
    private func installMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit KeyHeat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        NSApp.mainMenu = main
    }
}

@MainActor
final class DashboardWindowController {
    private var window: NSWindow?
    private let state: AppState

    init(state: AppState) { self.state = state }

    func show() {
        if window == nil {
            let root = DashboardView().environmentObject(state)
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 920),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable],
                             backing: .buffered, defer: false)
            w.title = "KeyHeat"
            w.contentViewController = NSHostingController(rootView: root)
            w.contentMinSize = NSSize(width: 940, height: 600)
            w.isReleasedWhenClosed = false
            w.center()
            w.setFrameAutosaveName("KeyHeat.Dashboard")
            window = w
            installSnapshotHook(on: w)
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Dev hook: KEYHEAT_SNAPSHOT=/path/out.png renders the dashboard to a PNG
    /// and quits. KEYHEAT_SNAPSHOT_SCROLL scrolls the page first;
    /// KEYHEAT_SNAPSHOT_INNER_SCROLL scrolls the first nested list.
    private func installSnapshotHook(on w: NSWindow) {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["KEYHEAT_SNAPSHOT"] else { return }
        let height = Double(env["KEYHEAT_SNAPSHOT_HEIGHT"] ?? "") ?? 2300
        w.setFrame(NSRect(x: 0, y: 0, width: 1180, height: height), display: true)
        let scroll = Double(env["KEYHEAT_SNAPSHOT_SCROLL"] ?? "") ?? 0
        let inner = Double(env["KEYHEAT_SNAPSHOT_INNER_SCROLL"] ?? "") ?? 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let scrollViews = Self.findScrollViews(in: w.contentView)
            if scroll > 0, let sv = scrollViews.first {
                sv.contentView.scroll(to: NSPoint(x: 0, y: scroll))
                sv.reflectScrolledClipView(sv.contentView)
            }
            if inner > 0, let sv = scrollViews.dropFirst().first {
                sv.contentView.scroll(to: NSPoint(x: 0, y: inner))
                sv.reflectScrolledClipView(sv.contentView)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if let view = w.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                if let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: URL(fileURLWithPath: path))
                }
            }
            NSLog("KeyHeat: snapshot written to \(path), window frame \(w.frame)")
            NSApp.terminate(nil)
        }
    }

    /// Every scroll view under `view`, outermost first.
    private static func findScrollViews(in view: NSView?) -> [NSScrollView] {
        guard let view else { return [] }
        var found: [NSScrollView] = []
        if let sv = view as? NSScrollView { found.append(sv) }
        for sub in view.subviews { found += findScrollViews(in: sub) }
        return found
    }
}
