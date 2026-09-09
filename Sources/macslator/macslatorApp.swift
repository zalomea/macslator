import SwiftUI

@main
struct macslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            TranslatorView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .help) {
                Button("macslator Help") {
                    appState.showHelp()
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static weak var shared: AppDelegate?

    private var expandedFrame: NSRect?
    private let collapsedSize: NSSize = NSSize(width: 80, height: 80)

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        configureFloatingWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.log("Application is terminating, releasing resources…")
        Translator.shared.cancelPendingWork()
    }

    @MainActor
    func setCollapsed(_ collapsed: Bool) {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }

            if collapsed {
                // Save current frame before collapsing
                self.expandedFrame = window.frame

                // Calculate collapsed frame centered on current window center
                let currentFrame = window.frame
                let collapsedOrigin = NSPoint(
                    x: currentFrame.midX - self.collapsedSize.width / 2,
                    y: currentFrame.midY - self.collapsedSize.height / 2
                )
                let collapsedFrame = NSRect(origin: collapsedOrigin, size: self.collapsedSize)

                window.setFrame(collapsedFrame, display: true, animate: true)
                window.contentMinSize = self.collapsedSize
                window.contentMaxSize = self.collapsedSize
            } else {
                // Restore expanded frame or use default size
                let targetFrame = self.expandedFrame ?? self.defaultExpandedFrame()
                window.setFrame(targetFrame, display: true, animate: true)
                window.contentMinSize = NSSize(width: 520, height: 400)
                window.contentMaxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            }
        }
    }

    private func defaultExpandedFrame() -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 200, y: 200, width: 600, height: 480)
        }
        let size = NSSize(width: 600, height: 480)
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        )
        return NSRect(origin: origin, size: size)
    }

    private func configureFloatingWindow() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .transient]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
        }
    }
}
