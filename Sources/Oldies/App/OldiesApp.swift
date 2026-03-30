// OldiesApp.swift
// Oldies – Swedish AI assistant for Meta Ray-Ban glasses
//
// Entry point. Initializes the Meta Wearables SDK once and
// wires the URL-callback handler for the Meta AI OAuth flow.

import SwiftUI
import MWDATCore

@main
struct OldiesApp: App {

    @StateObject private var glasses = GlassesManager.shared
    @StateObject private var settings = AppSettings.shared

    init() {
        configureWearables()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(glasses)
                .environmentObject(settings)
                // Handle Universal Link / custom-scheme callback from Meta AI app
                .onOpenURL { url in
                    Task {
                        try? await Wearables.shared.handleUrl(url)
                    }
                }
        }
    }

    // MARK: – SDK initialisation (call once at launch)
    private func configureWearables() {
        do {
            try Wearables.configure()
        } catch {
            assertionFailure("Wearables SDK configure failed: \(error)")
        }
    }
}
