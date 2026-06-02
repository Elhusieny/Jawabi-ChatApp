//
//  VoiceMessageBubble.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 21/04/2026.
//

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
                if !player.isLoading {
                    player.togglePlayback(url: audioURL)
                }
            } label: {
                if player.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: isCurrentUser ? .white : .blue))
                        .scaleEffect(0.8)
                        .frame(width: 34, height: 34)
                } else {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(isCurrentUser ? .white : .blue)
                }
            }
            .disabled(player.isLoading)
            
            VStack(alignment: .leading, spacing: 4) {
                // Progress bar with seek gesture
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * player.progress, height: 4)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let percentage = min(max(0, value.location.x / geo.size.width), 1)
                                player.seek(to: percentage)
                            }
                    )
                }
                .frame(height: 4)

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
        .onAppear {
            // Preload audio to get duration without playing
            if player.totalDuration == nil && !player.isLoading {
                player.preloadAudio(url: audioURL)
            }
        }
        .onDisappear {
            player.stop()
        }
    }
    
    private func formatDuration(_ t: TimeInterval) -> String {
        let mins = Int(t) / 60
        let secs = Int(t) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Voice Player ViewModel
class VoicePlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval?
    @Published var isLoading = false

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var currentURL: String?
    
    // MARK: - Public Methods
    
    func preloadAudio(url: String) {
        guard !isLoading else { return }
        isLoading = true
        
        guard let url = URL(string: url) else {
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self, let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    let tempPlayer = try AVAudioPlayer(data: data)
                    self.totalDuration = tempPlayer.duration
                    self.isLoading = false
                    print("✅ Voice preloaded, duration: \(self.totalDuration ?? 0) seconds")
                } catch {
                    print("Failed to preload: \(error)")
                    self.isLoading = false
                }
            }
        }.resume()
    }
    
    func togglePlayback(url: String) {
        if isLoading { return }
        
        if isPlaying {
            stop()
            return
        }

        if currentURL != url {
            loadAudio(from: url)
        } else {
            play()
        }
    }
    
    func seek(to percentage: Double) {
        guard let player = audioPlayer else { return }
        
        let newTime = player.duration * percentage
        player.currentTime = newTime
        currentTime = newTime
        progress = percentage
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

    // MARK: - Private Methods
    
    private func loadAudio(from urlString: String) {
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }

        print("🎵 Loading voice message from: \(urlString)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self, let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                    
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    self.audioPlayer?.delegate = self
                    self.audioPlayer?.prepareToPlay()
                    self.totalDuration = self.audioPlayer?.duration
                    self.currentURL = urlString
                    self.isLoading = false
                    
                    print("✅ Audio loaded, duration: \(self.totalDuration ?? 0) seconds")
                    self.play()
                } catch {
                    print("❌ Voice playback error: \(error)")
                    self.isLoading = false
                }
            }
        }.resume()
    }
    
    private func play() {
        guard let player = audioPlayer else { return }
        
        player.play()
        isPlaying = true
        
        // Start timer to update progress
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let p = self.audioPlayer, p.isPlaying else {
                if self?.isPlaying == true {
                    DispatchQueue.main.async {
                        self?.stop()
                    }
                }
                return
            }
            DispatchQueue.main.async {
                self.currentTime = p.currentTime
                self.progress = p.duration > 0 ? p.currentTime / p.duration : 0
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.stop()
        }
    }
}
