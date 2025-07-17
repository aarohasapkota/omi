import 'dart:async';
import 'package:flutter/services.dart';
import 'package:omi/backend/http/api/messages.dart';
import 'package:omi/backend/http/api/conversations.dart';
import 'package:omi/backend/preferences.dart';
import 'package:omi/providers/conversation_provider.dart';
import 'package:omi/providers/capture_provider.dart';
import 'package:omi/utils/logger.dart';

class HotkeyService {
  static const MethodChannel _channel = MethodChannel('omi/hotkey');
  static HotkeyService? _instance;
  
  static HotkeyService get instance {
    _instance ??= HotkeyService._();
    return _instance!;
  }
  
  HotkeyService._() {
    _setupMethodChannelHandler();
  }
  
  bool _isEnabled = false;
  bool _hasPermission = false;
  
  // Getters
  bool get isEnabled => _isEnabled;
  bool get hasPermission => _hasPermission;
  
  // Callbacks for UI updates
  Function(bool)? onPermissionChanged;
  Function(bool)? onHotkeyStateChanged;
  Function(String)? onError;
  
  void _setupMethodChannelHandler() {
    _channel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'onHotkeyActivated':
            Logger.info('Global hotkey activated');
            break;
            
          case 'onPermissionStatusChanged':
            final hasPermission = call.arguments['hasPermission'] as bool? ?? false;
            _hasPermission = hasPermission;
            onPermissionChanged?.call(hasPermission);
            Logger.info('Permission status changed: $hasPermission');
            break;
            
          case 'onHotkeyRegistered':
            final success = call.arguments['success'] as bool? ?? false;
            _isEnabled = success;
            onHotkeyStateChanged?.call(success);
            if (!success) {
              final error = call.arguments['error'] as String? ?? 'Unknown error';
              onError?.call(error);
              Logger.error('Hotkey registration failed: $error');
            } else {
              Logger.info('Hotkey registered successfully');
            }
            break;
            
          case 'onHotkeyUnregistered':
            _isEnabled = false;
            onHotkeyStateChanged?.call(false);
            Logger.info('Hotkey unregistered');
            break;
            
          case 'forwardToFlutterChat':
            return await _handleChatMessage(call.arguments);
            
          case 'getFlutterChatHistory':
            return await _getChatHistory(call.arguments);
            
          case 'startFlutterVoiceRecording':
            return await _startVoiceRecording();
            
          default:
            Logger.warning('Unknown method call: ${call.method}');
        }
      } catch (e, stackTrace) {
        Logger.handle(e, stackTrace, message: 'Error handling method call ${call.method}');
        rethrow;
      }
    });
  }
  
  // Public API methods
  
  Future<bool> initialize() async {
    try {
      // Check current permission status
      final result = await _channel.invokeMethod('checkPermissions');
      _hasPermission = result['hasPermission'] as bool? ?? false;
      
      if (_hasPermission) {
        // If we have permission, register the hotkey
        await registerHotkey();
      }
      
      return true;
    } catch (e, stackTrace) {
      Logger.handle(e, stackTrace, message: 'Failed to initialize hotkey service');
      onError?.call('Failed to initialize hotkey service: $e');
      return false;
    }
  }
  
  Future<bool> registerHotkey() async {
    try {
      final result = await _channel.invokeMethod('registerHotkey');
      final success = result['success'] as bool? ?? false;
      _isEnabled = success;
      onHotkeyStateChanged?.call(success);
      return success;
    } catch (e, stackTrace) {
      Logger.handle(e, stackTrace, message: 'Failed to register hotkey');
      onError?.call('Failed to register hotkey: $e');
      return false;
    }
  }
  
  Future<bool> unregisterHotkey() async {
    try {
      final result = await _channel.invokeMethod('unregisterHotkey');
      final success = result['success'] as bool? ?? false;
      if (success) {
        _isEnabled = false;
        onHotkeyStateChanged?.call(false);
      }
      return success;
    } catch (e, stackTrace) {
      Logger.handle(e, stackTrace, message: 'Failed to unregister hotkey');
      onError?.call('Failed to unregister hotkey: $e');
      return false;
    }
  }
  
  Future<bool> requestPermissions() async {
    try {
      await _channel.invokeMethod('requestPermissions');
      return true;
    } catch (e, stackTrace) {
      Logger.handle(e, stackTrace, message: 'Failed to request permissions');
      onError?.call('Failed to request permissions: $e');
      return false;
    }
  }
  
  Future<bool> showChatWindow() async {
    try {
      final result = await _channel.invokeMethod('showChatWindow');
      return result['success'] as bool? ?? false;
    } catch (e, stackTrace) {
      Logger.handle(e, stackTrace, message: 'Failed to show chat window');
      return false;
    }
  }
  
  Future<bool> hideChatWindow() async {
    try {
      final result = await _channel.invokeMethod('hideChatWindow');
      return result['success'] as bool? ?? false;
    } catch (e, stackTrace) {
      Logger.handle(e, stackTrace, message: 'Failed to hide chat window');
      return false;
    }
  }
  
  // Private methods for handling SwiftUI requests
  
  Future<Map<String, dynamic>> _handleChatMessage(Map<dynamic, dynamic> arguments) async {
    try {
      final message = arguments['message'] as String;
      final timestamp = arguments['timestamp'] as String?;
      
      Logger.info('Received chat message from SwiftUI: $message');
      
      // TODO: Integrate with your existing chat API
      // This is where you'll call your existing message API
      // For now, returning a mock response
      
      // Example integration with existing chat API:
      // final response = await sendMessage(message);
      
      // Mock response for now
      final response = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'response': 'This is a mock response to: $message',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      return response;
    } catch (e, stackTrace) {
      Logger.handle(e, stackTrace, message: 'Failed to handle chat message');
      throw PlatformException(
        code: 'CHAT_ERROR',
        message: 'Failed to process chat message: $e',
      );
    }
  }
  
  Future<List<Map<String, dynamic>>> _getChatHistory(Map<dynamic, dynamic> arguments) async {
    try {
      final limit = arguments['limit'] as int? ?? 3;
      
      Logger.info('Fetching chat history with limit: $limit');
      
      // TODO: Integrate with your existing chat history API
      // This is where you'll call your existing conversation API
      
      // Example integration:
      // final conversations = await getConversations(limit: limit);
      // return conversations.map((c) => c.toMap()).toList();
      
      // Mock response for now
      return [
        {
          'id': '1',
          'text': 'Hello! How can I help you today?',
          'isUser': false,
          'timestamp': DateTime.now().subtract(Duration(minutes: 5)).toIso8601String(),
        },
        {
          'id': '2', 
          'text': 'I need help with something',
          'isUser': true,
          'timestamp': DateTime.now().subtract(Duration(minutes: 4)).toIso8601String(),
        },
        {
          'id': '3',
          'text': 'Of course! What would you like help with?',
          'isUser': false,
          'timestamp': DateTime.now().subtract(Duration(minutes: 3)).toIso8601String(),
        },
      ];
    } catch (e, stackTrace) {
      Logger.handle(e, stackTrace, message: 'Failed to get chat history');
      return [];
    }
  }
  
  Future<Map<String, dynamic>> _startVoiceRecording() async {
    try {
      Logger.info('Starting voice recording from SwiftUI');
      
      // TODO: Integrate with your existing voice recording functionality
      // This is where you'll call your existing capture provider
      
      // Example integration:
      // final captureProvider = CaptureProvider();
      // await captureProvider.startRecording();
      
      return {
        'success': true,
        'message': 'Voice recording started',
      };
    } catch (e, stackTrace) {
      Logger.handle(e, stackTrace, message: 'Failed to start voice recording');
      throw PlatformException(
        code: 'VOICE_ERROR',
        message: 'Failed to start voice recording: $e',
      );
    }
  }
  
  void dispose() {
    unregisterHotkey();
    _instance = null;
  }
}