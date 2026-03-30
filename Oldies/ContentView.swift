import SwiftUI

struct ContentView: View {
    @StateObject private var oauth = OAuthHandler.shared
    @StateObject private var glasses = GlassesManager.shared

    var body: some View {
        Group {
            if !oauth.isAuthorized {
                AuthorizationView()
            } else {
                MainView()
            }
        }
        .animation(.easeInOut, value: oauth.isAuthorized)
    }
}

// MARK: - Authorization screen

struct AuthorizationView: View {
    @ObservedObject private var oauth = OAuthHandler.shared

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "eyeglasses")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Oldies")
                .font(.largeTitle.bold())

            Text("Connect your Meta Ray-Ban glasses to get started.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button {
                oauth.requestAuthorization()
            } label: {
                Label("Connect with Meta", systemImage: "link")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)

            if let error = oauth.authError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

// MARK: - Main screen

struct MainView: View {
    @ObservedObject private var glasses = GlassesManager.shared
    @State private var aiResponse: String = ""
    @State private var isThinking = false
    @State private var question = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Connection status
                    StatusBar()

                    // Live photo from glasses
                    PhotoCard()

                    // AI response
                    if !aiResponse.isEmpty {
                        AIResponseCard(text: aiResponse)
                    }

                    // Ask a question
                    QuestionBar(question: $question, isThinking: $isThinking) {
                        await askQuestion()
                    }

                    // Describe what glasses see
                    DescribeButton(isThinking: $isThinking) {
                        await describeScene()
                    }
                }
                .padding()
            }
            .navigationTitle("Oldies")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BatteryView()
                }
            }
        }
        .onAppear {
            if glasses.connectionStatus == .disconnected {
                glasses.connect()
            }
        }
    }

    private func describeScene() async {
        guard let photo = glasses.lastPhoto else { return }
        isThinking = true
        defer { isThinking = false }
        do {
            aiResponse = try await AIService.shared.describe(imageData: photo)
        } catch {
            aiResponse = "Error: \(error.localizedDescription)"
        }
    }

    private func askQuestion() async {
        guard !question.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let q = question
        question = ""
        isThinking = true
        defer { isThinking = false }
        do {
            aiResponse = try await AIService.shared.answer(question: q)
        } catch {
            aiResponse = "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Sub-views

struct StatusBar: View {
    @ObservedObject private var glasses = GlassesManager.shared

    var body: some View {
        HStack {
            Circle()
                .fill(glasses.connectionStatus == .connected ? .green : .orange)
                .frame(width: 10, height: 10)
            Text(glasses.connectionStatus.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if glasses.connectionStatus == .disconnected {
                Button("Reconnect") { glasses.connect() }
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct PhotoCard: View {
    @ObservedObject private var glasses = GlassesManager.shared

    var body: some View {
        Group {
            if let data = glasses.lastPhoto, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 220)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                            Text("No photo yet")
                                .foregroundStyle(.tertiary)
                        }
                    }
            }
        }
    }
}

struct AIResponseCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI Response", systemImage: "sparkles")
                .font(.caption.bold())
                .foregroundStyle(.blue)
            Text(text)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct QuestionBar: View {
    @Binding var question: String
    @Binding var isThinking: Bool
    let onSubmit: () async -> Void

    var body: some View {
        HStack {
            TextField("Ask anything…", text: $question)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit {
                    Task { await onSubmit() }
                }
            Button {
                Task { await onSubmit() }
            } label: {
                Image(systemName: isThinking ? "ellipsis" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .disabled(isThinking)
        }
    }
}

struct DescribeButton: View {
    @ObservedObject private var glasses = GlassesManager.shared
    @Binding var isThinking: Bool
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            Label(isThinking ? "Thinking…" : "Describe what I see",
                  systemImage: "eye.fill")
                .frame(maxWidth: .infinity)
                .padding()
                .background(glasses.lastPhoto == nil ? Color(.systemGray4) : .blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(glasses.lastPhoto == nil || isThinking)
    }
}

struct BatteryView: View {
    @ObservedObject private var glasses = GlassesManager.shared

    var body: some View {
        if let level = glasses.batteryLevel {
            Label("\(level)%", systemImage: batteryIcon(level))
                .font(.caption)
                .foregroundStyle(level < 20 ? .red : .secondary)
        }
    }

    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case 76...: return "battery.100"
        case 51...: return "battery.75"
        case 26...: return "battery.50"
        case 11...: return "battery.25"
        default:    return "battery.0"
        }
    }
}

#Preview {
    ContentView()
}
