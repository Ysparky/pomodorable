import SwiftUI

struct SnackbarView: View {
    let message: String
    let isVisible: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Text(message)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
                .padding(.trailing)
            }
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
    }
}

#Preview {
    ZStack {
        Color.gray
        SnackbarView(
            message: "Los cambios se aplicarán en la siguiente sesión",
            isVisible: true,
            onDismiss: {}
        )
    }
} 