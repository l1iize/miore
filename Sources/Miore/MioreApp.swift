import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allObjects.forEach { window in
            window.styleMask.insert(.resizable)
            window.minSize = NSSize(width: 640, height: 480)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = false
        }
    }
}

extension NSWindow {
    static var allObjects: [NSWindow] { NSApplication.shared.windows }
}

@main
struct MioreApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = AppModel()

    init() {
        MioreFont.registerBundledFont()
    }

    var body: some Scene {
        WindowGroup("Miore") {
            RootView(model: model)
                .frame(minWidth: 640, minHeight: 480)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Miore") {
                Button(L10n.t("command.refresh")) { model.refresh() }.keyboardShortcut("r")
                Button(L10n.t("command.launch")) { model.launchSelected() }.keyboardShortcut(.return, modifiers: [.command])
            }
        }
    }
}
