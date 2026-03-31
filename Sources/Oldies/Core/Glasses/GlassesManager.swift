// GlassesManager.swift
// Oldies
//
// Wraps the Meta Wearables Device Access Toolkit (MWDATCore + MWDATCamera).
// Uses the real v0.5.0 API surface derived from the compiled swiftinterface.

import Foundation
import SwiftUI
import MWDATCore
import MWDATCamera

/// Observable singleton - inject via @EnvironmentObject in SwiftUI views.
@MainActor
final class GlassesManager: ObservableObject {

    static let shared = GlassesManager()

    // MARK: - Published state
    @Published var registrationState: RegistrationState = .unavailable
    @Published var connectedDeviceId: String?
    @Published var cameraPermission: PermissionStatus?
    @Published var streamState: StreamSessionState = .stopped
    @Published var latestFrame: UIImage?
    @Published var latestPhoto: Data?
    @Published var error: String?

    // MARK: - Private
    private var streamSession: StreamSession?
    private var frameToken: (any AnyListenerToken)?
    private var photoToken: (any AnyListenerToken)?
    private var stateToken: (any AnyListenerToken)?
    private var registrationTask: Task<Void, Never>?
    private var devicesTask: Task<Void, Never>?

    private init() {
        observeRegistrationState()
        observeDevices()
    }

    // MARK: - Registration

    func startRegistration() {
        Task {
            do {
                try await Wearables.shared.startRegistration()
            } catch {
                self.error = "Registration failed: \(error.localizedDescription)"
            }
        }
    }

    func stopRegistration() {
        Task {
            do {
                try await Wearables.shared.startUnregistration()
            } catch {
                self.error = "Unregistration failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Camera permissions

    func checkAndRequestCameraPermission() async {
        let wearables = Wearables.shared
        do {
            let status = try await wearables.checkPermissionStatus(.camera)
            cameraPermission = status
            if status != .granted {
                let newStatus = try await wearables.requestPermission(.camera)
                cameraPermission = newStatus
            }
        } catch {
            self.error = "Camera permission error: \(error.localizedDescription)"
        }
    }

    // MARK: - Camera stream

    func startStream() async {
        guard let deviceId = connectedDeviceId else {
            error = "No device connected"
            return
        }
        await checkAndRequestCameraPermission()
        guard cameraPermission == .granted else {
            error = "Camera permission not granted"
            return
        }
        let selector = SpecificDeviceSelector(device: deviceId)
        let config = StreamSessionConfig(videoCodec: .hvc1, resolution: .medium, frameRate: 15)
        let session = StreamSession(streamSessionConfig: config, deviceSelector: selector)
        self.streamSession = session
        frameToken = session.videoFramePublisher.listen { [weak self] frame in
            guard let image = frame.makeUIImage() else { return }
            Task { @MainActor [weak self] in self?.latestFrame = image }
        }
        photoToken = session.photoDataPublisher.listen { [weak self] photoData in
            Task { @MainActor [weak self] in self?.latestPhoto = photoData.data }
        }
        stateToken = session.statePublisher.listen { [weak self] state in
            Task { @MainActor [weak self] in self?.streamState = state }
        }
        await session.start()
    }

    func stopStream() {
        Task {
            await streamSession?.stop()
            await frameToken?.cancel()
            await photoToken?.cancel()
            await stateToken?.cancel()
            streamSession = nil
            frameToken = nil
            photoToken = nil
            stateToken = nil
        }
    }

    @discardableResult
    func capturePhoto() -> Bool {
        return streamSession?.capturePhoto(format: .jpeg) ?? false
    }

    // MARK: - Private observers

    private func observeRegistrationState() {
        registrationTask = Task { [weak self] in
            for await state in Wearables.shared.registrationStateStream() {
                await MainActor.run { self?.registrationState = state }
            }
        }
    }

    private func observeDevices() {
        devicesTask = Task { [weak self] in
            for await devices in Wearables.shared.devicesStream() {
                await MainActor.run { self?.connectedDeviceId = devices.first }
            }
        }
    }
}
