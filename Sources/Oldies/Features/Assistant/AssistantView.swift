// AssistantView.swift
// Oldies
//
// Main screen: shows conversation history, mic button, camera button.

import SwiftUI

struct AssistantView: View {

    @StateObject private var vm = AssistantViewModel()
    @EnvironmentObject  private var glasses: GlassesManager
    @State private var textInput = ""
    @FocusState private var textFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ─── Chat history ──────────────────────────────────────────
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(vm.messages) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id.uuidString)
                            }

                            if vm.isThinking {
                                ThinkingIndicator()
                                    .id("thinking")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: vm.messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(vm.messages.last?.id.uuidString ?? "thinking", anchor: .bottom)
                        }
                    }
                }

                // ─── Live transcript while recording ─────────────────────
                if vm.isRecording && !vm.currentTranscript.isEmpty {
                    Text(vm.currentTranscript)
                        .font(.callout.italic())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                // ─── Input bar ────────────────────────────────────────────
                HStack(spacing: 12) {
                    // Text input
                    TextField("Fråga något…", text: $textInput, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .focused($textFocused)
                        .submitLabel(.send)
                        .onSubmit { sendText() }

                    // Camera capture
                    Button {
                        textFocused = false
                        Task { await vm.captureAndDescribe() }
                    } label: {
                        Image(systemName: "camera.viewfinder")
                            .font(.title2)
                            .foregroundStyle(glasses.latestFrame != nil ? .blue : .gray)
                    }
                    .disabled(glasses.streamState != .streaming)

                    // Mic button
                    Button {
                        textFocused = false
                        vm.toggleRecording()
                    } label: {
                        Image(systemName: vm.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(vm.isRecording ? .red : .blue)
                            .symbolEffect(.bounce, value: vm.isRecording)
                    }

                    // Send text button (only visible when text entered)
                    if !textInput.isEmpty {
                        Button(action: sendText) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Oldies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ConnectionStatusButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        // TTS playing indicator
                        if vm.isSpeaking {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.blue)
                                .symbolEffect(.pulse)
                        }
                        Button {
                            vm.clearConversation()
                        } label: {
                            Image(systemName: "trash")
                        }
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .alert("Fel", isPresented: .constant(vm.errorBanner != nil)) {
                Button("OK") { vm.errorBanner = nil }
            } message: {
                Text(vm.errorBanner ?? "")
            }
        }
    }

    private func sendText() {
        let q = textInput.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        textInput = ""
        Task { await vm.sendMessage(q) }
    }
}

// MARK: – Sub-views

struct MessageBubble: View {
    let message: AssistantViewModel.ChatMessage

    var isUser: Bool { message.sender == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Attached image (from camera capture)
                if let imgData = message.imageData,
                   let uiImage = UIImage(data: imgData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if !message.text.isEmpty {
                    Text(message.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(isUser ? Color.blue : Color(.secondarySystemBackground))
                        .foregroundStyle(isUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }
}

struct ThinkingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animate ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animate)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear { animate = true }
    }
}

struct ConnectionStatusButton: View {
    @EnvironmentObject var glasses: GlassesManager

    var body: some View {
        Button {
            if glasses.registrationState != .registered {
                glasses.startRegistration()
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusLabel)
                    .font(.caption)
            }
        }
    }

    private var statusColor: Color {
        switch glasses.registrationState {
        case .registered:   return glasses.connectedDeviceId != nil ? .green : .yellow
        default:             return .red
        }
    }

    private var statusLabel: String {
        switch glasses.registrationState {
        case .registered:   return glasses.connectedDeviceId != nil ? "Ansluten" : "Väntar på glasögon"
        default:             return "Anslut"
        }
    }
}

#Preview {
    AssistantView()
        .environmentObject(GlassesManager.shared)
        .environmentObject(AppSettings.shared)
}
