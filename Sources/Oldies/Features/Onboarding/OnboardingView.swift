// OnboardingView.swift
// Oldies
//
// Shown on first launch. Guides user through:
//   1. Connecting glasses via Meta AI app
//   2. Setting up an AI provider key

import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject private var glasses: GlassesManager
    @EnvironmentObject private var settings: AppSettings
    @AppStorage("onboarding_done") private var onboardingDone = false

    @State private var step = 0

    var body: some View {
        TabView(selection: $step) {
            WelcomePage()        .tag(0)
            ConnectGlassesPage() .tag(1)
            AIProviderPage()     .tag(2)
            ReadyPage {
                onboardingDone = true
            }                    .tag(3)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .animation(.easeInOut, value: step)
    }
}

// MARK: – Pages

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "eyeglasses")
                .font(.system(size: 90))
                .foregroundStyle(.blue)
            Text("Oldies")
                .font(.largeTitle.bold())
            Text("Din svenska AI-assistent i Meta Ray-Ban-glasögonen.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
        }
    }
}

private struct ConnectGlassesPage: View {
    @EnvironmentObject var glasses: GlassesManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "link.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            Text("Anslut glasögonen")
                .font(.title.bold())
            Text("""
                Du behöver Meta AI-appen på din telefon.
                Tryck på knappen nedan för att öppna Meta AI och bevilja åtkomst.
                """)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if glasses.registrationState == .registered {
                Label("Ansluten!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3.bold())
            } else {
                Button {
                    glasses.startRegistration()
                } label: {
                    Label("Anslut via Meta AI", systemImage: "link")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
            }
            Spacer()
        }
    }
}

private struct AIProviderPage: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showKey = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "cpu.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            Text("Välj AI-leverantör")
                .font(.title.bold())

            Picker("Leverantör", selection: $settings.aiProvider) {
                ForEach(AIProviderType.allCases) { p in
                    Text(p.rawValue).tag(p.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if settings.selectedProvider == .openAI {
                SecureField("OpenAI API-nyckel", text: $settings.openAIKey)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
            } else if settings.selectedProvider == .ollama {
                TextField("Ollama URL", text: $settings.ollamaURL)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .padding(.horizontal)
                Text("Din Ollama-server på \(settings.ollamaURL)")
                    .font(.caption).foregroundStyle(.secondary)
            } else if settings.selectedProvider == .claude {
                SecureField("Anthropic API-nyckel", text: $settings.claudeKey)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
            }
            Spacer()
        }
    }
}

private struct ReadyPage: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            Text("Du är redo!")
                .font(.largeTitle.bold())
            Text("Sätt på glasögonen, tryck på mikrofonen och börja prata på svenska.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button(action: onDone) {
                Text("Kom igång")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(GlassesManager.shared)
        .environmentObject(AppSettings.shared)
}
