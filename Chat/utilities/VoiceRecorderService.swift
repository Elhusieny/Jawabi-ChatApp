import AVFoundation
import Foundation

class VoiceRecorderService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingURL: URL?
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    private let audioFilename = "voice_note_\(Date().timeIntervalSince1970).m4a"
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func startRecording() throws {
        // Reset state
        recordingDuration = 0
        isPaused = false
        recordingStartTime = Date()
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(audioFilename)
        recordingURL = audioURL
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.prepareToRecord()
        audioRecorder?.record()
        
        isRecording = true
        
        // Start timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
    }
    
    func pauseRecording() {
        audioRecorder?.pause()
        isPaused = true
        recordingTimer?.invalidate()
    }
    
    func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
        recordingStartTime = Date().addingTimeInterval(-recordingDuration)
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        isRecording = false
        isPaused = false
        
        let duration = recordingDuration
        recordingDuration = 0
        
        // Only return URL if duration > 0.5 seconds (avoid very short recordings)
        guard duration > 0.5, let url = recordingURL else {
            return nil
        }
        
        return url
    }
    
    private func updateDuration() {
        guard let startTime = recordingStartTime else { return }
        recordingDuration = Date().timeIntervalSince(startTime)
    }
    
    func cancelRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        isRecording = false
        isPaused = false
        recordingDuration = 0
        
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            cancelRecording()
        }
    }
}
