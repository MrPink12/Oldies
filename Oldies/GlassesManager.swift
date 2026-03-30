import Foundation
import MetaWearableDAT
import Combine

/// Manages the connection to the Meta Ray-Ban glasses and sensor data streams.
class GlassesManager: ObservableObject {
    static let shared = GlassesManager()

    // MARK: - Published state
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastPhoto: Data?
    @Published var transcript: String = ""
    @Published var batteryLevel: Int?
    @Published var errorMessage: String?

    enum ConnectionStatus {
        case disconnected, connecting, connected
        var label: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting:   return "Connecting..."
            case .connected:    return "Connected"
            }
        }
    }

    private var session: MWDATSession?
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Connection

    func connect() {
        connectionStatus = .connecting
        errorMessage = nil

        MWDATSession.start { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let session):
                    self?.session = session
                    self?.connectionStatus = .connected
                    self?.subscribeToSensors(session)
                case .failure(let error):
                    self?.connectionStatus = .disconnected
                    self?.errorMessage = "Connection failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func disconnect() {
        session?.stop()
        session = nil
        connectionStatus = .disconnected
        cancellables.removeAll()
    }

    // MARK: - Sensor subscriptions

    private func subscribeToSensors(_ session: MWDATSession) {
        // Camera feed — subscribe to photos captured on the glasses
        session.cameraPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] imageData in
                self?.lastPhoto = imageData
            }
            .store(in: &cancellables)

        // Voice / microphone transcription from the glasses
        session.transcriptPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.transcript = text
            }
            .store(in: &cancellables)

        // Battery level
        session.batteryPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.batteryLevel = level
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// Capture a photo from the glasses camera.
    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        guard let session else {
            completion(.failure(GlassesError.notConnected))
            return
        }
        session.capturePhoto(completion: completion)
    }
}

enum GlassesError: LocalizedError {
    case notConnected
    var errorDescription: String? {
        switch self {
        case .notConnected: return "Glasses are not connected."
        }
    }
}
