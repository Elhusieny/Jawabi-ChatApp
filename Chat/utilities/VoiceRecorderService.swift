import AVFoundation
import Combine

class VoiceRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 30)

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var levelTimer: Timer?
    private var recordingURL: URL?

    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try session.setActive(true)

        let fileName = "voice_\(Int(Date().timeIntervalSince1970)).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        isRecording = true
        recordingDuration = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.recordingDuration += 1
        }
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            self.audioRecorder?.updateMeters()
            let level = self.audioRecorder?.averagePower(forChannel: 0) ?? -60
            let normalized = max(0, (level + 60) / 60)
            self.audioLevels.removeFirst()
            self.audioLevels.append(normalized)
        }

        return url
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        timer?.invalidate()
        levelTimer?.invalidate()
        isRecording = false
        audioLevels = Array(repeating: 0, count: 30)
        return recordingURL
    }

    func cancelRecording() {
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        timer?.invalidate()
        levelTimer?.invalidate()
        isRecording = false
        recordingURL = nil
        recordingDuration = 0
        audioLevels = Array(repeating: 0, count: 30)
    }
}