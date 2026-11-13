import AppKit
import Combine
import ServiceManagement
import UniformTypeIdentifiers

enum TrackingState {
    case active, paused, noPermission
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var stats = Stats()
    @Published var range: TimeRange = .today { didSet { refresh(force: true) } }
    @Published var scale: HeatScale = .sqrt
    @Published var showCounts = false
    /// Remembered across launches.
    @Published var typingLayout = AppState.initialTypingLayout {
        didSet {
            UserDefaults.standard.set(typingLayout.rawValue, forKey: AppState.typingLayoutKey)
            refresh(force: true)
        }
    }
    /// Restrict the board and every figure to letters and , . / ; '.
    @Published var lettersAndPunctuation = false { didSet { refresh(force: true) } }
    @Published var keyRanking: KeyRanking = .most
    @Published var showSpecialKeys = true
    @Published private(set) var tracking: TrackingState = .noPermission
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    /// Set by the app delegate; opens the dashboard window.
    var showDashboard: () -> Void = {}

    let store: KeyStore
    let tap = KeyTap()

    private var lastGeneration = -1
    private var computing = false
    /// A forced refresh arrived while computing; run it once the compute lands.
    private var refreshPending = false
    private var uiTimer: Timer?
    private var retryTimer: Timer?

    init() {
        let env = ProcessInfo.processInfo.environment
        if let override = env["KEYHEAT_DB"] {
            // Dev/demo hook: point at a different database file.
            store = KeyStore(url: URL(fileURLWithPath: override))
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let dir = support.appendingPathComponent("KeyHeat", isDirectory: true)
            store = KeyStore(url: dir.appendingPathComponent("keyheat.sqlite"))
        }

        let store = self.store
        tap.onKeyPress = { code in store.record(code: code) }

        uiTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        if let r = env["KEYHEAT_RANGE"].flatMap(TimeRange.init(rawValue:)) { range = r }
        if let k = env["KEYHEAT_RANK"].flatMap(KeyRanking.init(rawValue:)) { keyRanking = k }
        if env["KEYHEAT_HIDE_SPECIAL"] != nil { showSpecialKeys = false }
        if env["KEYHEAT_LETTERS_AND_PUNCTUATION"] != nil { lettersAndPunctuation = true }
        refresh(force: true)
        if env["KEYHEAT_NO_TAP"] != nil {
            // Dev/demo hook: never create the event tap or ask for permission.
            tracking = .paused
        } else {
            startTracking()
        }
    }

    private static let typingLayoutKey = "typingLayout"

    /// The saved layout. KEYHEAT_LAYOUT overrides it for snapshots without
    /// being saved; assigning in init would run `didSet` and save it.
    private static var initialTypingLayout: TypingLayout {
        let raw = ProcessInfo.processInfo.environment["KEYHEAT_LAYOUT"]
            ?? UserDefaults.standard.string(forKey: typingLayoutKey)
        return raw.flatMap(TypingLayout.init(rawValue:)) ?? .qwerty
    }

    static var tapDisabledByEnvironment: Bool {
        ProcessInfo.processInfo.environment["KEYHEAT_NO_TAP"] != nil
    }

    // MARK: Tracking

    func startTracking() {
        if tap.start() {
            tracking = .active
            retryTimer?.invalidate()
            retryTimer = nil
        } else {
            tracking = .noPermission
            if retryTimer == nil {
                // Poll until the user grants Input Monitoring.
                retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.startTracking() }
                }
            }
        }
    }

    func togglePause() {
        switch tracking {
        case .active:
            tap.setEnabled(false)
            tracking = .paused
        case .paused:
            tap.setEnabled(true)
            tracking = .active
        case .noPermission:
            startTracking()
        }
    }

    func openInputMonitoringSettings() {
        KeyTap.requestPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func relaunch() {
        store.flushSync()
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", path]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: Stats

    func refresh(force: Bool = false) {
        let snap = store.snapshot()
        guard !computing else {
            // Dropping this would leave a new range or layout unapplied until
            // the next key press.
            if force { refreshPending = true }
            return
        }
        guard force || snap.generation != lastGeneration else { return }
        lastGeneration = snap.generation
        computing = true
        let range = self.range
        let layout = self.typingLayout
        let lettersAndPunctuation = self.lettersAndPunctuation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Stats.compute(buckets: snap.buckets, range: range, layout: layout,
                                       lettersAndPunctuation: lettersAndPunctuation)
            Task { @MainActor in
                guard let self else { return }
                self.stats = result
                self.computing = false
                if self.refreshPending {
                    self.refreshPending = false
                    self.refresh(force: true)
                }
            }
        }
    }

    // MARK: Settings & data

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("KeyHeat: launch at login failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func resetAllData() {
        store.reset()
        refresh(force: true)
    }

    func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "keyheat-\(range.rawValue).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var csv = "keycode,name,category,count,share\n"
        for k in stats.perKey {
            let share = String(format: "%.4f", stats.share(k.count))
            csv += "\(k.info.code),\"\(k.info.name)\",\"\(k.info.category.name)\",\(k.count),\(share)\n"
        }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}
