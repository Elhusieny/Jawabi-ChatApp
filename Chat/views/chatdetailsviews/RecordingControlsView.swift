// MARK: - Recording Controls View
struct RecordingControlsView: View {
    let recorder: VoiceRecorderService
    let onSend: (URL) -> Void
    let onCancel: () -> Void
    
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    
    private var primaryColor: Color { .jawabiPrimary }
    
    var body: some View {
        HStack(spacing: 12) {
            // Cancel button
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            
            // Recording waveform animation
            HStack(spacing: 3) {
                ForEach(0..<12) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(primaryColor)
                        .frame(width: 3, height: recordingBars[index])
                        .animation(
                            Animation.easeInOut(duration: 0.3)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.05),
                            value: recordingBars[index]
                        )
                }
            }
            .frame(height: 30)
            
            // Recording time
            Text(formatTime(recordingTime))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(primaryColor)
                .monospacedDigit()
            
            Spacer()
            
            // Send button
            Button(action: {
                if let url = recorder.stopRecording() {
                    onSend(url)
                }
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - Recording Bars Animation
    private var recordingBars: [CGFloat] {
        let baseHeights: [CGFloat] = [8, 12, 18, 24, 30, 24, 18, 12, 8, 6, 10, 14]
        // Randomize heights slightly for live effect
        return baseHeights.map { height in
            let randomFactor = CGFloat.random(in: 0.6...1.4)
            return height * randomFactor
        }
    }
    
    // MARK: - Timer Methods
    private func startTimer() {
        recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Format Time
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time - Double(Int(time))) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Voice Recorder Service
class VoiceRecorderService: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingDuration: TimeInterval = 0
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func startRecording() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setActive(true)
        
        let fileName = "voice_\(Date().timeIntervalSince1970).m4a"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)
        recordingURL = audioURL
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
        audioRecorder?.record()
        isRecording = true
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        return recordingURL
    }
    
    func cancelRecording() {
        audioRecorder?.stop()
        isRecording = false
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
    }
}

// MARK: - Time Extension
extension TimeInterval {
    func formattedTime() -> String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview
struct RecordingControlsView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingControlsView(
            recorder: VoiceRecorderService(),
            onSend: { _ in },
            onCancel: {}
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}