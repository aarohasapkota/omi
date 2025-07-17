import Cocoa
import HotKey
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var hotKey: HotKey?
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupHotKey()
    }

    func setupHotKey() {
        hotKey = HotKey(key: .space, modifiers: [.option])
        hotKey?.keyDownHandler = { [weak self] in
            self?.toggleWindow()
        }
    }

    func toggleWindow() {
        if window?.isVisible == true {
            window?.orderOut(nil)
            return
        }

        let view = ChatView()
        let hosting = NSHostingController(rootView: view)

        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 800, height: 600)
        let windowSize = CGSize(width: 420, height: 100)
        let windowRect = NSRect(
            x: (screenSize.width - windowSize.width) / 2,
            y: (screenSize.height - windowSize.height) / 2,
            width: windowSize.width,
            height: windowSize.height
        )

        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.level = .floating
        window?.titleVisibility = .hidden
        window?.titlebarAppearsTransparent = true
        window?.contentView = hosting.view
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
