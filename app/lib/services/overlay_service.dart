import 'package:flutter/material.dart';
import 'package:omi/widgets/overlay_chat_widget.dart';
import 'package:omi/main.dart';

class OverlayService {
  static final OverlayService _instance = OverlayService._internal();
  factory OverlayService() => _instance;
  OverlayService._internal();

  OverlayEntry? _overlayEntry;
  bool _isVisible = false;

  void toggleOverlay() {
    if (_isVisible) {
      hideOverlay();
    } else {
      showOverlay();
    }
  }

  void showOverlay() {
    if (_overlayEntry != null) return;

    // Get the current context and show overlay
    final context = MyApp.navigatorKey.currentContext;
    if (context == null) {
      print('Warning: Navigator context not available for overlay');
      return;
    }
    
    try {
      final overlay = Overlay.of(context);
      
      _overlayEntry = OverlayEntry(
        builder: (context) => OverlayChatWidget(
          onClose: hideOverlay,
        ),
      );

      overlay.insert(_overlayEntry!);
      _isVisible = true;
    } catch (e) {
      print('Error showing overlay: $e');
    }
  }

  void hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isVisible = false;
  }
}