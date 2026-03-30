// RootView.swift
// Oldies
//
// Entry point view. Shows OnboardingView on first launch,
// then AssistantView thereafter. The switch is driven by
// @AppStorage("onboarding_done") so it persists across restarts.

import SwiftUI

struct RootView: View {

    @AppStorage("onboarding_done") private var onboardingDone = false

    var body: some View {
        if onboardingDone {
            AssistantView()
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(GlassesManager.shared)
        .environmentObject(AppSettings.shared)
}
