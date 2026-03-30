import Foundation
import MetaWearableDAT

/// Handles the OAuth callback from the Meta AI app.
/// When the user grants permission, Meta AI app redirects to:
///   https://hagstroem.net/oldies?...
/// which iOS resolves as a Universal Link and opens this app.
class OAuthHandler: ObservableObject {
    static let shared = OAuthHandler()

    @Published var isAuthorized = false
    @Published var authError: String?

    private init() {}

    func handleCallback(url: URL) {
        guard url.host == "hagstroem.net",
              url.path.hasPrefix("/oldies") else { return }

        // Pass the URL to the Meta DAT SDK to complete authorization
        MWDATAuth.handleOpenURL(url) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isAuthorized = true
                    self?.authError = nil
                case .failure(let error):
                    self?.authError = error.localizedDescription
                }
            }
        }
    }

    /// Starts the OAuth flow — opens the Meta AI app for permission grant.
    func requestAuthorization() {
        MWDATAuth.authorize { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isAuthorized = true
                    self?.authError = nil
                case .failure(let error):
                    self?.authError = error.localizedDescription
                }
            }
        }
    }
}
