import SwiftUI

struct ChatView: View {
    @State private var inputText = ""

    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask anything", text: $inputText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
                .padding(.leading, 12)
                .frame(height: 44)

            Spacer()

            Button(action: {
                print("Voice/mic button tapped")
            }) {
                Image(systemName: "waveform.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.white)
                    .padding(.trailing, 12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(height: 60)
        .background(Color.black.opacity(0.95))
        .cornerRadius(14)
        .padding()
    }
}
