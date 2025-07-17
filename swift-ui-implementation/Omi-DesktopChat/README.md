# Omi Desktop Chat

A native macOS SwiftUI application for voice-powered conversations with AI, inspired by the Omi wearable project.

## Features

- 🎤 **Voice Input**: Record and transcribe your voice questions using Apple's Speech Recognition
- ⌨️ **Global Hotkey**: Press `Opt+Space` anywhere on your Mac to quickly access the chat
- 💬 **Chat Interface**: Beautiful, modern chat UI similar to the original design
- 🔧 **Configurable**: Support for different AI models and API keys
- 🎯 **Native macOS**: Built with SwiftUI for optimal performance and integration

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Microphone permissions
- OpenAI API key (or compatible API)

## Setup

1. Open `OmiDesktopChat.xcodeproj` in Xcode
2. Build and run the project
3. Grant microphone permissions when prompted
4. Open Settings (gear icon) to configure your API key
5. Start chatting with voice or text!

## Global Hotkey

Press `Opt+Space` (Option + Space) anywhere on your Mac to:
- Bring the chat window to the front
- Start voice recording immediately
- Ask questions without switching apps

## API Configuration

The app supports OpenAI's ChatGPT API by default. In Settings, you can:
- Enter your OpenAI API key
- Select different models (GPT-4, GPT-3.5-turbo, etc.)
- Configure the global hotkey

## Architecture

- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive data flow
- **AVFoundation**: Audio recording
- **Speech**: Voice-to-text transcription
- **Carbon**: Global hotkey registration

## File Structure

```
OmiDesktopChat/
├── OmiDesktopChatApp.swift     # Main app entry point
├── ContentView.swift           # Root view
├── ChatView.swift              # Chat interface
├── SettingsView.swift          # Configuration panel
├── ChatService.swift           # API communication
├── AudioRecorder.swift         # Voice recording & STT
├── GlobalHotKey.swift          # System-wide shortcuts
└── Assets.xcassets/            # App icons and resources
```

## Contributing

This project is inspired by the open-source Omi wearable project. Feel free to contribute improvements, bug fixes, or new features!

## License

MIT License - feel free to use this code in your own projects.
