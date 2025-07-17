import SwiftUI
import FlutterMacOS

struct ChatMessage: Identifiable {
    let id: String
    let text: String
    let isUser: Bool
    let timestamp: Date
}

struct ChatView: View {
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isExpanded = false
    @State private var isRecording = false
    
    private let methodChannel: FlutterMethodChannel?
    private let onClose: () -> Void
    
    init(methodChannel: FlutterMethodChannel?, onClose: @escaping () -> Void) {
        self.methodChannel = methodChannel
        self.onClose = onClose
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                // Chat history
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 300)
                .background(Color.black.opacity(0.1))
            }
            
            // Input area
            HStack {
                TextField("Ask me anything...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }) {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .foregroundColor(isRecording ? .red : .blue)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button("Send") {
                    sendMessage()
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 420, height: isExpanded ? 400 : 100)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            loadRecentMessages()
            setupNotificationObservers()
        }
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
    
    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        // Add user message immediately
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            text: message,
            isUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Expand to show conversation
        isExpanded = true
        
        // Send to Flutter
        methodChannel?.invokeMethod("forwardToFlutterChat", arguments: [
            "message": message,
            "timestamp": Date().timeIntervalSince1970
        ]) { result in
            if let response = result as? [String: Any],
               let responseText = response["response"] as? String {
                DispatchQueue.main.async {
                    let aiMessage = ChatMessage(
                        id: UUID().uuidString,
                        text: responseText,
                        isUser: false,
                        timestamp: Date()
                    )
                    self.messages.append(aiMessage)
                }
            }
        }
        
        inputText = ""
    }
    
    private func startRecording() {
        isRecording = true
        methodChannel?.invokeMethod("startFlutterVoiceRecording", arguments: nil) { result in
            // Handle recording start result
        }
    }
    
    private func stopRecording() {
        isRecording = false
        // Stop recording logic would go here
    }
    
    private func loadRecentMessages() {
        methodChannel?.invokeMethod("getFlutterChatHistory", arguments: ["limit": 3]) { result in
            if let messagesData = result as? [[String: Any]] {
                DispatchQueue.main.async {
                    self.messages = messagesData.compactMap { data in
                        guard let id = data["id"] as? String,
                              let text = data["text"] as? String,
                              let isUser = data["isUser"] as? Bool else { return nil }
                        
                        return ChatMessage(
                            id: id,
                            text: text,
                            isUser: isUser,
                            timestamp: Date()
                        )
                    }
                    
                    if !self.messages.isEmpty {
                        self.isExpanded = true
                    }
                }
            }
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ChatMessageReceived"),
            object: nil,
            queue: .main
        ) { notification in
            if let message = notification.object as? ChatMessage {
                messages.append(message)
                isExpanded = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ChatHistoryUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            if let messagesData = notification.object as? [[String: Any]] {
                messages = messagesData.compactMap { data in
                    guard let id = data["id"] as? String,
                          let text = data["text"] as? String,
                          let isUser = data["isUser"] as? Bool else { return nil }
                    
                    return ChatMessage(
                        id: id,
                        text: text,
                        isUser: isUser,
                        timestamp: Date()
                    )
                }
                if !messages.isEmpty {
                    isExpanded = true
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 250, alignment: .trailing)
            } else {
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 250, alignment: .leading)
                Spacer()
            }
        }
    }
}

#Preview {
    ChatView(methodChannel: nil, onClose: {})
        .frame(width: 420, height: 400)
}
