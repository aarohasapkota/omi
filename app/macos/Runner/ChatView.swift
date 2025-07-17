import SwiftUI
import FlutterMacOS

struct ChatView: View {
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var messages: [ChatMessage] = []
    
    // Flutter integration
    weak var methodChannel: FlutterMethodChannel?
    var onDismiss: (() -> Void)?
    
    init(methodChannel: FlutterMethodChannel? = nil, onDismiss: (() -> Void)? = nil) {
        self.methodChannel = methodChannel
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages history (if any recent messages)
            if !messages.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages.suffix(3)) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                .frame(maxHeight: 120)
                .background(Color.black.opacity(0.95))
            }
            
            // Input area
            HStack(spacing: 12) {
                TextField("Ask anything", text: $inputText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .padding(.leading, 12)
                    .frame(height: 44)
                    .onSubmit {
                        sendMessage()
                    }
                    .disabled(isLoading)

                Spacer()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                        .padding(.trailing, 12)
                } else {
                    Button(action: {
                        if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // Voice/mic button when no text
                            startVoiceRecording()
                        } else {
                            // Send button when there's text
                            sendMessage()
                        }
                    }) {
                        Image(systemName: inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "waveform.circle.fill" : "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.white)
                            .padding(.trailing, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(height: 60)
            .background(Color.black.opacity(0.95))
        }
        .cornerRadius(14)
        .padding()
        .onAppear {
            loadRecentMessages()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ChatMessageReceived"))) { notification in
            if let message = notification.object as? ChatMessage {
                withAnimation {
                    messages.append(message)
                }
            }
        }
    }
    
    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        isLoading = true
        
        // Add user message to UI immediately
        let userMessage = ChatMessage(id: UUID().uuidString, text: message, isUser: true, timestamp: Date())
        withAnimation {
            messages.append(userMessage)
        }
        
        // Clear input
        inputText = ""
        
        // Send to Flutter via method channel
        methodChannel?.invokeMethod("sendMessage", arguments: [
            "message": message,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = result as? FlutterError {
                    print("❌ Error sending message: \(error.message ?? "Unknown error")")
                    // Could show error message in UI
                } else if let response = result as? [String: Any] {
                    // Handle successful response
                    if let responseText = response["response"] as? String {
                        let botMessage = ChatMessage(
                            id: response["id"] as? String ?? UUID().uuidString,
                            text: responseText,
                            isUser: false,
                            timestamp: Date()
                        )
                        withAnimation {
                            messages.append(botMessage)
                        }
                    }
                }
            }
        }
    }
    
    private func startVoiceRecording() {
        print("🎤 Voice recording started")
        
        // Call Flutter method to start voice recording
        methodChannel?.invokeMethod("startVoiceRecording", arguments: nil) { result in
            DispatchQueue.main.async {
                if let error = result as? FlutterError {
                    print("❌ Error starting voice recording: \(error.message ?? "Unknown error")")
                }
            }
        }
    }
    
    private func loadRecentMessages() {
        // Load recent chat messages from Flutter
        methodChannel?.invokeMethod("getRecentMessages", arguments: ["limit": 3]) { result in
            DispatchQueue.main.async {
                if let messagesData = result as? [[String: Any]] {
                    let chatMessages = messagesData.compactMap { messageDict -> ChatMessage? in
                        guard let id = messageDict["id"] as? String,
                              let text = messageDict["text"] as? String,
                              let isUser = messageDict["isUser"] as? Bool else {
                            return nil
                        }
                        
                        let timestamp: Date
                        if let timestampString = messageDict["timestamp"] as? String {
                            timestamp = ISO8601DateFormatter().date(from: timestampString) ?? Date()
                        } else {
                            timestamp = Date()
                        }
                        
                        return ChatMessage(id: id, text: text, isUser: isUser, timestamp: timestamp)
                    }
                    
                    withAnimation {
                        messages = chatMessages
                    }
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
            }
            
            Text(message.text)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(message.isUser ? Color.blue.opacity(0.8) : Color.gray.opacity(0.6))
                )
                .frame(maxWidth: 200, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

// Data model for chat messages
struct ChatMessage: Identifiable, Equatable {
    let id: String
    let text: String
    let isUser: Bool
    let timestamp: Date
}
