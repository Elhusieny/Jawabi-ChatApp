
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
struct CompactRecordingView: View {
    @ObservedObject var recorder: VoiceRecorderService
    let onSend: (URL) -> Void
    let onCancel: () -> Void
    @State private var animateWaveform = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Cancel button
            Button(action: onCancel) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.title3)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Recording indicator and waveform
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .scaleEffect(recorder.isRecording && !recorder.isPaused ? 1.2 : 1.0)
                    .animation(recorder.isRecording && !recorder.isPaused ?
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true) :
                        .default,
                        value: recorder.isRecording && !recorder.isPaused)
                
                // Animated waveform bars
                HStack(spacing: 3) {
                    ForEach(0..<12, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.blue)
                            .frame(width: 2, height: getWaveformHeight(index: index))
                            .animation(
                                recorder.isRecording && !recorder.isPaused ?
                                    .easeInOut(duration: 0.3).repeatForever(autoreverses: true).delay(Double(index) * 0.05) :
                                    .default,
                                value: animateWaveform
                            )
                    }
                }
                .onAppear {
                    animateWaveform.toggle()
                }
            }
            
            // Timer
            Text(formatDuration(recorder.recordingDuration))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .frame(minWidth: 60)
            
            Spacer()
            
            // Pause/Resume button
            Button(action: {
                if recorder.isPaused {
                    recorder.resumeRecording()
                } else {
                    recorder.pauseRecording()
                }
            }) {
                Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Send button
            Button(action: {
                if let url = recorder.stopRecording() {
                    onSend(url)
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(recorder.recordingDuration > 0.5 ? .green : .gray)
                    .font(.title3)
                    .padding(8)
                    .background(recorder.recordingDuration > 0.5 ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            .disabled(recorder.recordingDuration < 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(25)
    }
    
    private func getWaveformHeight(index: Int) -> CGFloat {
        if recorder.isPaused || !recorder.isRecording {
            return 8
        }
        
        // Create varying heights based on index and time
        let phase = Date().timeIntervalSince1970 * 8 + Double(index)
        let height = 8 + abs(sin(phase)) * 12
        return max(5, min(25, height))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
