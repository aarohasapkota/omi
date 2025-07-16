import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:omi/services/overlay_service.dart';

class HotkeyService {
  static final HotkeyService _instance = HotkeyService._internal();
  factory HotkeyService() => _instance;
  HotkeyService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Register Option+Space hotkey
      HotKey hotKey = HotKey(
        key: LogicalKeyboardKey.space,
        modifiers: [HotKeyModifier.alt],
        scope: HotKeyScope.system,
      );

      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) {
          OverlayService().toggleOverlay();
        },
      );
      
      _isInitialized = true;
    } catch (e) {
      print('Failed to register hotkey: $e');
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      try {
        await hotKeyManager.unregisterAll();
        _isInitialized = false;
      } catch (e) {
        print('Failed to unregister hotkeys: $e');
      }
    }
  }
}