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

    try {
      // Get the overlay state directly from the navigator
      final navigatorState = MyApp.navigatorKey.currentState;
      if (navigatorState == null) {
        print('Warning: Navigator state not available for overlay');
        return;
      }
      
      final overlayState = navigatorState.overlay;
      if (overlayState == null) {
        print('Warning: Overlay state not found');
        return;
      }
      
      _overlayEntry = OverlayEntry(
        builder: (context) => OverlayChatWidget(
          onClose: hideOverlay,
        ),
      );

      overlayState.insert(_overlayEntry!);
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