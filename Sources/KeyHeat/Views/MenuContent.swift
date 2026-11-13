import AppKit
import SwiftUI

struct MenuContent: View {
    @EnvironmentObject private var state: AppState

    private var statusLine: String {
        switch state.tracking {
        case .active: return "Tracking key presses"
        case .paused: return "Tracking paused"
        case .noPermission: return "Waiting for Input Monitoring permission"
        }
    }

    var body: some View {
        Text("Today: \(state.stats.todayEveryKey.formatted()) presses")
        Text(statusLine)
        Divider()
        Button("Open Dashboard") { state.showDashboard() }
            .keyboardShortcut("d")
        Button(state.tracking == .paused ? "Resume Tracking" : "Pause Tracking") { state.togglePause() }
            .disabled(state.tracking == .noPermission)
        if state.tracking == .noPermission {
            Button("Grant Input Monitoring…") { state.openInputMonitoringSettings() }
        }
        Divider()
        Toggle("Launch at Login", isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))
        Divider()
        Button("Quit KeyHeat") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
