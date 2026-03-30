import SwiftUI

@main
struct OldiesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle Universal Link callback from Meta AI app OAuth
                    OAuthHandler.shared.handleCallback(url: url)
                }
        }
    }
}
