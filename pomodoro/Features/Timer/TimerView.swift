import SwiftUI

struct TimerView: View {
    @EnvironmentObject var viewModel: TimerViewModel
    @StateObject private var colorService = ColorService.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // Session Counter
                Text("Sesiones completadas: \(viewModel.completedSessions)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                // Timer Display
                ZStack {
                    Circle()
                        .stroke(lineWidth: 20)
                        .opacity(0.3)
                        .foregroundColor(colorScheme == .dark ? .white : .gray)
                    
                    Circle()
                        .trim(from: 0.0, to: viewModel.progress)
                        .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                        .foregroundColor(viewModel.isWorkMode ? colorService.colors.workColor : colorService.colors.breakColor)
                        .rotationEffect(Angle(degrees: 270.0))
                        .animation(.linear, value: viewModel.progress)
                    
                    VStack {
                        Text(viewModel.timeString)
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        Text(viewModel.modeText)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 300, height: 300)
                .padding()
                
                // Control Buttons
                HStack(spacing: 30) {
                    Button(action: viewModel.resetTimer) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    
                    Button(action: viewModel.toggleTimer) {
                        Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
            }
            .padding()
            .background(colorScheme == .dark ? Color.black : Color.white)
            
            // Snackbar overlay
            SnackbarView(
                message: "Los cambios se aplicarán en la siguiente sesión",
                isVisible: viewModel.showConfigUpdateMessage,
                onDismiss: viewModel.dismissConfigMessage
            )
        }
    }
}

#Preview {
    TimerView()
        .environmentObject(TimerViewModel())
} 