import SwiftUI

@main
struct OmiDesktopChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No window here — we're managing it manually
        Settings {
            EmptyView() // prevent default UI
        }
    }
}
