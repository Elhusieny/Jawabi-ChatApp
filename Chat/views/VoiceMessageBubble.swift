import SwiftUI
import AVFoundation

struct VoiceMessageBubble: View {
    let audioURL: String
    let isCurrentUser: Bool
    let duration: TimeInterval? // optional hint from server

    @StateObject private var player = VoicePlayerViewModel()

    private var bubbleGradient: LinearGradient {
        isCurrentUser
            ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [Color(.systemGray5), Color(.systemGray4)], startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Play / pause button
            Button {
                player.togglePlayback(url: audioURL)
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(isCurrentUser ? .white : .blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * player.progress, height: 4)
                    }
                }
                .frame(height: 4)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // will be calculated inside VoicePlayerViewModel
                        }
                )

                // Duration label
                Text(player.isPlaying ? formatDuration(player.currentTime) : formatDuration(player.totalDuration ?? duration ?? 0))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(bubbleGradient)
        .cornerRadius(18)
        .frame(maxWidth: 220)
        .onDisappear { player.stop() }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let mins = Int(t) / 60
        let secs = Int(t) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// Lightweight player viewmodel — one per bubble
class VoicePlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval?

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var currentURL: String?

    func togglePlayback(url: String) {
        if isPlaying { stop(); return }

        if currentURL != url {
            loadAudio(from: url)
        } else {
            play()
        }
    }

    private func loadAudio(from urlString: String) {
        guard let url = URL(string: urlString) else { return }

        // For remote URLs, download first
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data else { return }
            DispatchQueue.main.async {
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback)
                    try AVAudioSession.sharedInstance().setActive(true)
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    self.audioPlayer?.delegate = self
                    self.totalDuration = self.audioPlayer?.duration
                    self.currentURL = urlString
                    self.play()
                } catch {
                    print("❌ Voice playback error: \(error)")
                }
            }
        }.resume()
    }

    private func play() {
        audioPlayer?.play()
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let p = self.audioPlayer else { return }
            self.currentTime = p.currentTime
            self.progress = p.duration > 0 ? p.currentTime / p.duration : 0
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        progress = 0
        currentTime = 0
        timer?.invalidate()
        timer = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.stop() }
    }
}