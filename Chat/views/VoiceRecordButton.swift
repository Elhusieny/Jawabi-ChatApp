struct VoiceRecordButton: View {
    @Binding var isRecording: Bool
    let onStop: (URL?) -> Void

    @StateObject private var recorder = VoiceRecorderService()
    @State private var startURL: URL?

    var body: some View {
        Button {
            if isRecording {
                let url = recorder.stopRecording()
                isRecording = false
                onStop(url)
            } else {
                recorder.requestPermission { granted in
                    guard granted else { return }
                    startURL = try? recorder.startRecording()
                    isRecording = true
                }
            }
        } label: {
            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.title2)
                .foregroundStyle(
                    isRecording
                        ? LinearGradient(colors: [.red], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                )
                .scaleEffect(isRecording ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)
        }
    }
}