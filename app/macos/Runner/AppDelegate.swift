import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var hotkeyPlugin: HotkeyPlugin?

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    super.applicationDidFinishLaunching(aNotification)
    
    // Register the hotkey plugin manually
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    let registrar = controller.registrar(forPlugin: "HotkeyPlugin")
    HotkeyPlugin.register(with: registrar)
    hotkeyPlugin = HotkeyPlugin()
  }
}
