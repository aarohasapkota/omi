import Cocoa
import Carbon.HIToolbox
import Combine
import FlutterMacOS

class GlobalHotKey: ObservableObject {
    private var hotKeyRef: EventHotKeyRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x68746B31), id: UInt32(1)) // 'htk1' in hex
    private var eventHandlerRef: EventHandlerRef?
    
    @Published var isEnabled = true
    @Published var hasInputMonitoringPermission = false
    
    var onActivation: (() -> Void)?
    
    // Flutter method channel for communication
    weak var methodChannel: FlutterMethodChannel?
    
    init(methodChannel: FlutterMethodChannel? = nil) {
        self.methodChannel = methodChannel
        checkInputMonitoringPermission()
        registerHotKey()
    }
    
    deinit {
        unregisterHotKey()
    }
    
    func checkInputMonitoringPermission() {
        // Check if we have input monitoring permission
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        
        DispatchQueue.main.async {
            self.hasInputMonitoringPermission = accessibilityEnabled
            
            // Notify Flutter about permission status
            self.methodChannel?.invokeMethod("onPermissionStatusChanged", arguments: [
                "hasPermission": accessibilityEnabled
            ])
        }
        
        if accessibilityEnabled {
            print("✅ Input monitoring permission granted")
        } else {
            print("❌ Input monitoring permission required - please grant in System Preferences > Security & Privacy > Privacy > Input Monitoring")
        }
    }
    
    func registerHotKey() {
        unregisterHotKey() // Ensure we don't have duplicate registrations
        
        guard isEnabled else { return }
        
        // Re-check permission
        checkInputMonitoringPermission()
        
        // Define hotkey: Option + Space
        let modifierFlags: UInt32 = UInt32(optionKey)
        let keyCode: UInt32 = UInt32(kVK_Space)
        
        // Register the hotkey
        var tempHotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifierFlags, hotKeyID,
                                       GetApplicationEventTarget(), 0, &tempHotKeyRef)
        
        if status == OSStatus(noErr) {
            hotKeyRef = tempHotKeyRef
            installEventHandler()
            print("🔥 Global hotkey registered successfully (Option+Space)")
            
            // Notify Flutter about successful registration
            methodChannel?.invokeMethod("onHotkeyRegistered", arguments: ["success": true])
        } else {
            print("❌ Failed to register global hotkey, status: \(status)")
            
            // Notify Flutter about registration failure
            methodChannel?.invokeMethod("onHotkeyRegistered", arguments: [
                "success": false,
                "error": "Failed to register hotkey with status: \(status)"
            ])
        }
    }
    
    func unregisterHotKey() {
        // Remove event handler
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
            print("🔴 Event handler removed")
        }
        
        // Unregister hotkey
        if let hotKeyRef = hotKeyRef {
            let status = UnregisterEventHotKey(hotKeyRef)
            if status == OSStatus(noErr) {
                print("� Global hotkey unregistered")
            } else {
                print("⚠️ Failed to unregister hotkey, status: \(status)")
            }
            self.hotKeyRef = nil
        }
        
        // Notify Flutter about unregistration
        methodChannel?.invokeMethod("onHotkeyUnregistered", arguments: nil)
    }
    
    private func installEventHandler() {
        // Define event specification for hotkey events
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), 
                                    eventKind: UInt32(kEventHotKeyPressed))
        
        // Create event handler callback
        let eventHandler: EventHandlerUPP = { (nextHandler, eventRef, userData) -> OSStatus in
            guard let eventRef = eventRef else { return OSStatus(eventNotHandledErr) }
            
            // Extract hotkey ID from event
            var receivedHotKeyID = EventHotKeyID()
            let getEventStatus = GetEventParameter(eventRef, 
                                                 EventParamName(kEventParamDirectObject),
                                                 EventParamType(typeEventHotKeyID), 
                                                 nil,
                                                 MemoryLayout.size(ofValue: receivedHotKeyID),
                                                 nil, 
                                                 &receivedHotKeyID)
            
            if getEventStatus == OSStatus(noErr) {
                // Get the GlobalHotKey instance from user data
                if let userData = userData {
                    let globalHotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                    
                    // Check if this is our hotkey
                    if receivedHotKeyID.signature == globalHotKey.hotKeyID.signature && 
                       receivedHotKeyID.id == globalHotKey.hotKeyID.id {
                        print("🎯 Hotkey detected: Option+Space")
                        
                        // Call the activation handler on main thread
                        DispatchQueue.main.async {
                            globalHotKey.onActivation?()
                            
                            // Notify Flutter about hotkey activation
                            globalHotKey.methodChannel?.invokeMethod("onHotkeyActivated", arguments: nil)
                        }
                        
                        return OSStatus(noErr)
                    }
                }
            }
            
            return OSStatus(eventNotHandledErr)
        }
        
        // Install the event handler
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), 
                                              eventHandler, 
                                              1, 
                                              &eventSpec, 
                                              userData, 
                                              &eventHandlerRef)
        
        if installStatus == OSStatus(noErr) {
            print("✅ Event handler installed successfully")
        } else {
            print("❌ Failed to install event handler, status: \(installStatus)")
        }
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            registerHotKey()
        } else {
            unregisterHotKey()
        }
    }
    
    func requestPermissionAndRegister() {
        checkInputMonitoringPermission()
        
        // Small delay to allow permission dialog to appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.registerHotKey()
        }
    }
}
