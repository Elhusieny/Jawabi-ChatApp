
//
//  VoiceRecordingView.swift
//  Chat
//

import SwiftUI

struct VoiceRecordingView: View {
    @Binding var isRecording: Bool
    @StateObject private var recorder = VoiceRecorderService()
    let onSend: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCancelConfirmation = false
    @State private var audioLevel: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Waveform visualization
            VStack(spacing: 16) {
                HStack(spacing: 4) {
                    ForEach(0..<30, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 3, height: getWaveformHeight(index: index))
                            .animation(
                                recorder.isPaused
                                    ? .none
                                    : .easeInOut(duration: 0.2).repeatForever(autoreverses: true),
                                value: audioLevel
                            )
                    }
                }
                .frame(height: 60)
                
                // Timer display
                Text(formatDuration(recorder.recordingDuration))
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            Spacer()
            
            // Control buttons
            HStack(spacing: 40) {
                // Cancel button
                Button(action: {
                    showingCancelConfirmation = true
                }) {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "trash")
                                    .font(.title)
                                    .foregroundColor(.red)
                            )
                        Text("Cancel")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Main recording button
                Button(action: {
                    if recorder.isPaused {
                        recorder.resumeRecording()
                    } else if recorder.isRecording {
                        recorder.pauseRecording()
                    } else {
                        // Start recording
                        recorder.requestPermission { granted in
                            guard granted else { return }
                            try? recorder.startRecording()
                        }
                    }
                }) {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(
                                recorder.isPaused
                                    ? LinearGradient(colors: [.green, .blue], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
                            )
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            )
                            .scaleEffect(recorder.isRecording && !recorder.isPaused ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recorder.isRecording && !recorder.isPaused)
                        
                        Text(recorder.isPaused ? "Resume" : "Pause")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Send button
                Button(action: {
                    if let url = recorder.stopRecording() {
                        onSend(url)
                        dismiss()
                    }
                }) {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            )
                        Text("Send")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .disabled(recorder.recordingDuration < 0.5)
                .opacity(recorder.recordingDuration < 0.5 ? 0.5 : 1)
            }
            .padding(.bottom, 40)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            // Start recording immediately when view appears
            recorder.requestPermission { granted in
                guard granted else { return }
                try? recorder.startRecording()
            }
        }
        .onDisappear {
            if recorder.isRecording {
                recorder.cancelRecording()
            }
        }
        .alert("Cancel Recording?", isPresented: $showingCancelConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Yes, Cancel", role: .destructive) {
                recorder.cancelRecording()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to cancel this voice recording? It will be deleted.")
        }
    }
    
    private func getWaveformHeight(index: Int) -> CGFloat {
        if recorder.isPaused || !recorder.isRecording {
            return 8
        }
        
        // Simulate audio levels (in real app, use actual audio power levels)
        let baseHeight: CGFloat = 10
        let variation = sin(Date().timeIntervalSince1970 * 10 + Double(index)) * 15
        let height = baseHeight + abs(variation)
        return max(8, min(45, height))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// MARK: - Compact Recording View (WhatsApp-Style Inline Recording)
// Add this new view for recording controls (replaces CompactRecordingView)
struct RecordingControlsView: View {
    @ObservedObject var recorder: VoiceRecorderService
    let onSend: (URL) -> Void
    let onCancel: () -> Void
    
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 16) {
            // Cancel button
            Button(action: {
                timer?.invalidate()
                timer = nil
                onCancel()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            
            // Recording indicator with waveform
            HStack(spacing: 4) {
                // Animated waveform while recording
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 4, height: CGFloat.random(in: 10...25))
                        .animation(
                            .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: UUID()
                        )
                }
                
                Text(formatDuration(recordingDuration))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            
            // Send button
            Button(action: {
                timer?.invalidate()
                timer = nil
                if let url = recorder.stopRecording() {
                    onSend(url)
                }
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 8)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startTimer() {
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration - Double(Int(duration))) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}
