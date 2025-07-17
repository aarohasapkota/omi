import Cocoa
import FlutterMacOS
import SwiftUI

class HotkeyPlugin: NSObject, FlutterPlugin {
    private var globalHotKey: GlobalHotKey?
    private var chatWindow: NSWindow?
    private var methodChannel: FlutterMethodChannel?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "omi/hotkey", binaryMessenger: registrar.messenger)
        let instance = HotkeyPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Initialize the global hotkey
        instance.initializeHotkey()
    }
    
    private func initializeHotkey() {
        globalHotKey = GlobalHotKey(methodChannel: methodChannel)
        globalHotKey?.onActivation = { [weak self] in
            self?.toggleChatWindow()
        }
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "registerHotkey":
            registerHotkey(result: result)
            
        case "unregisterHotkey":
            unregisterHotkey(result: result)
            
        case "checkPermissions":
            checkPermissions(result: result)
            
        case "requestPermissions":
            requestPermissions(result: result)
            
        case "showChatWindow":
            showChatWindow(result: result)
            
        case "hideChatWindow":
            hideChatWindow(result: result)
            
        case "sendMessage":
            handleSendMessage(call: call, result: result)
            
        case "getRecentMessages":
            handleGetRecentMessages(call: call, result: result)
            
        case "startVoiceRecording":
            handleStartVoiceRecording(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func registerHotkey(result: @escaping FlutterResult) {
        globalHotKey?.registerHotKey()
        result(["success": true])
    }
    
    private func unregisterHotkey(result: @escaping FlutterResult) {
        globalHotKey?.unregisterHotKey()
        result(["success": true])
    }
    
    private func checkPermissions(result: @escaping FlutterResult) {
        let hasPermission = globalHotKey?.hasInputMonitoringPermission ?? false
        result(["hasPermission": hasPermission])
    }
    
    private func requestPermissions(result: @escaping FlutterResult) {
        globalHotKey?.requestPermissionAndRegister()
        result(["success": true])
    }
    
    private func showChatWindow(result: @escaping FlutterResult) {
        toggleChatWindow()
        result(["success": true])
    }
    
    private func hideChatWindow(result: @escaping FlutterResult) {
        chatWindow?.orderOut(nil)
        result(["success": true])
    }
    
    private func toggleChatWindow() {
        if chatWindow?.isVisible == true {
            chatWindow?.orderOut(nil)
            return
        }
        
        let chatView = ChatView(methodChannel: methodChannel) { [weak self] in
            self?.chatWindow?.orderOut(nil)
        }
        let hosting = NSHostingController(rootView: chatView)
        
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 800, height: 600)
        let windowSize = CGSize(width: 420, height: 100)
        let windowRect = NSRect(
            x: (screenSize.width - windowSize.width) / 2,
            y: (screenSize.height - windowSize.height) / 2 + 100, // Slightly above center
            width: windowSize.width,
            height: windowSize.height
        )
        
        chatWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        chatWindow?.isOpaque = false
        chatWindow?.backgroundColor = .clear
        chatWindow?.level = .floating
        chatWindow?.titleVisibility = .hidden
        chatWindow?.titlebarAppearsTransparent = true
        chatWindow?.contentView = hosting.view
        chatWindow?.makeKeyAndOrderFront(nil)
        
        // Focus the window and bring the app to front
        NSApp.activate(ignoringOtherApps: true)
        
        // Auto-hide after some time of inactivity (optional)
        scheduleAutoHide()
    }
    
    private func scheduleAutoHide() {
        // Hide window after 30 seconds of inactivity
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            if self?.chatWindow?.isVisible == true {
                // Check if window still has focus, if not, hide it
                if self?.chatWindow?.isKeyWindow == false {
                    self?.chatWindow?.orderOut(nil)
                }
            }
        }
    }
    
    // MARK: - Flutter Communication Handlers
    
    private func handleSendMessage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let message = arguments["message"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing message", details: nil))
            return
        }
        
        // Forward the message to Flutter's chat service
        methodChannel?.invokeMethod("forwardToFlutterChat", arguments: [
            "message": message,
            "timestamp": arguments["timestamp"]
        ]) { flutterResult in
            result(flutterResult)
        }
    }
    
    private func handleGetRecentMessages(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        let limit = arguments?["limit"] as? Int ?? 3
        
        // Request recent messages from Flutter
        methodChannel?.invokeMethod("getFlutterChatHistory", arguments: ["limit": limit]) { flutterResult in
            result(flutterResult)
        }
    }
    
    private func handleStartVoiceRecording(result: @escaping FlutterResult) {
        // Forward voice recording request to Flutter
        methodChannel?.invokeMethod("startFlutterVoiceRecording", arguments: nil) { flutterResult in
            result(flutterResult)
        }
    }
    
    // MARK: - Public methods for Flutter to call
    
    func updateChatHistory(messages: [[String: Any]]) {
        // Notify SwiftUI about new messages
        NotificationCenter.default.post(
            name: NSNotification.Name("ChatHistoryUpdated"),
            object: messages
        )
    }
    
    func addMessage(_ message: [String: Any]) {
        // Add a single new message
        if let id = message["id"] as? String,
           let text = message["text"] as? String,
           let isUser = message["isUser"] as? Bool {
            
            let chatMessage = ChatMessage(
                id: id,
                text: text,
                isUser: isUser,
                timestamp: Date()
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("ChatMessageReceived"),
                object: chatMessage
            )
        }
    }
}
