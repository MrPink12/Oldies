// SettingsView.swift
// Oldies
//
// All settings: AI provider, API keys, voice, camera, system prompt.
// Changes are saved automatically via @AppStorage.

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var glasses: GlassesManager
    @State private var showModels = false
    @State private var availableModels: [String] = []
    @State private var isFetchingModels = false

    var body: some View {
        Form {

            // ─── Glasses connection ──────────────────────────────────────
            Section("Glasögon") {
                ConnectionRow()
                if let device = glasses.connectedDevice {
                    LabeledContent("Enhet", value: device.name ?? "Okänd")
                }
                CameraStreamRow()
            }

            // ─── AI Provider ─────────────────────────────────────────────
            Section("AI-leverantör") {
                Picker("Leverantör", selection: $settings.aiProvider) {
                    ForEach(AIProviderType.allCases) { provider in
                        Text(provider.rawValue).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            // ─── OpenAI ──────────────────────────────────────────────────
            if settings.selectedProvider == .openAI {
                Section("OpenAI") {
                    SecureField("API-nyckel", text: $settings.openAIKey)
                        .textContentType(.password)
                    HStack {
                        Text("Modell")
                        Spacer()
                        Text(settings.openAIModel)
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink("Välj OpenAI-modell") {
                        ModelPickerView(
                            selectedModel: $settings.openAIModel,
                            models: ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"]
                        )
                    }
                }
            }

            // ─── Ollama ──────────────────────────────────────────────────
            if settings.selectedProvider == .ollama {
                Section("Ollama (lokal AI)") {
                    TextField("Server-URL", text: $settings.ollamaURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    HStack {
                        Text("Modell")
                        Spacer()
                        Text(settings.ollamaModel)
                            .foregroundStyle(.secondary)
                    }
                    Button("Hämta modeller från server") {
                        Task { await fetchOllamaModels() }
                    }
                    .disabled(isFetchingModels)
                    if !availableModels.isEmpty {
                        NavigationLink("Välj Ollama-modell") {
                            ModelPickerView(
                                selectedModel: $settings.ollamaModel,
                                models: availableModels
                            )
                        }
                    }
                }
            }

            // ─── Claude ──────────────────────────────────────────────────
            if settings.selectedProvider == .claude {
                Section("Anthropic Claude") {
                    SecureField("API-nyckel", text: $settings.claudeKey)
                        .textContentType(.password)
                    NavigationLink("Välj Claude-modell") {
                        ModelPickerView(
                            selectedModel: $settings.claudeModel,
                            models: ["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5-20251001"]
                        )
                    }
                }
            }

            // ─── Voice ───────────────────────────────────────────────────
            Section("Röst") {
                Toggle("Lyssna automatiskt", isOn: $settings.autoListen)
                Toggle("Tala svar", isOn: $settings.speakResponses)
            }

            // ─── Camera ──────────────────────────────────────────────────
            Section("Kamera") {
                Toggle("Bifoga bild vid fråga", isOn: $settings.autoCaptureOnQuery)
            }

            // ─── System prompt ───────────────────────────────────────────
            Section {
                TextEditor(text: $settings.systemPrompt)
                    .frame(minHeight: 120)
            } header: {
                Text("Systemprompt")
            } footer: {
                Text("Instruerar assistenten om hur den ska bete sig. Ändra för att anpassa personlighet och svar.")
            }

            // ─── About ───────────────────────────────────────────────────
            Section("Om") {
                LabeledContent("GitHub", value: "MrPink12/Oldies")
                LabeledContent("Meta App-ID", value: "1958523175039520")
                LabeledContent("Bundle ID",   value: "com.hagstrom.oldies")
            }
        }
        .navigationTitle("Inställningar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fetchOllamaModels() async {
        isFetchingModels = true
        defer { isFetchingModels = false }
        let provider = OllamaProvider(baseURL: settings.ollamaURL, model: settings.ollamaModel)
        availableModels = (try? await provider.listModels()) ?? []
    }
}

// MARK: – Sub-views

struct ConnectionRow: View {
    @EnvironmentObject var glasses: GlassesManager

    var body: some View {
        HStack {
            Label("Status", systemImage: "eyeglasses")
            Spacer()
            switch glasses.registrationState {
            case .registered:
                Button("Koppla från") { glasses.stopRegistration() }
                    .foregroundStyle(.red)
            default:
                Button("Anslut glasögon") { glasses.startRegistration() }
                    .foregroundStyle(.blue)
            }
        }
    }
}

struct CameraStreamRow: View {
    @EnvironmentObject var glasses: GlassesManager

    var body: some View {
        HStack {
            Label("Kameraström", systemImage: "video")
            Spacer()
            switch glasses.streamState {
            case .streaming:
                Button("Stoppa") { glasses.stopStream() }
                    .foregroundStyle(.red)
            default:
                Button("Starta") {
                    Task { await glasses.startStream() }
                }
                .foregroundStyle(.blue)
                .disabled(glasses.connectedDevice == nil)
            }
        }
    }
}

struct ModelPickerView: View {
    @Binding var selectedModel: String
    let models: [String]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List(models, id: \.self) { model in
            Button {
                selectedModel = model
                dismiss()
            } label: {
                HStack {
                    Text(model)
                    Spacer()
                    if model == selectedModel {
                        Image(systemName: "checkmark").foregroundStyle(.blue)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .navigationTitle("Välj modell")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppSettings.shared)
            .environmentObject(GlassesManager.shared)
    }
}
