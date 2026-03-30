// GlassesManager.swift
// Oldies
//
// Central manager for the Meta Ray-Ban glasses connection.
// Wraps the Meta Wearables Device Access Toolkit (MWDATCore + MWDATCamera).
//
// Lifecycle:
//   1. App launches → OldiesApp calls Wearables.configure()
//   2. User taps "Connect" → startRegistration() opens Meta AI app
//   3. Meta AI app redirects back via Universal Link / URL scheme
//   4. OldiesApp.onOpenURL → Wearables.shared.handleUrl(url)
//   5. Registration resolves → devicesStream emits connected device
//   6. GlassesManager starts StreamSession for camera feed

import Foundation
import SwiftUI
import MWDATCore
import MWDATCamera

/// Observable singleton – inject via @EnvironmentObject in SwiftUI views.
@MainActor
final class GlassesManager: ObservableObject {

    static let shared = GlassesManager()

    // MARK: – Published state
    @Published var registrationState: RegistrationState = .unregistered
    @Published var connectedDevice: WearableDevice?
    @Published var cameraPermission: PermissionStatus = .denied
    @Published var streamState: StreamSessionState = .stopped
    @Published var latestFrame: UIImage?
    @Published var latestPhoto: Data?
    @Published var error: String?

    // MARK: – Private
    private var streamSession: StreamSession?
    private var frameToken: Any?
    private var photoToken: Any?
    private var registrationTask: Task<Void, Never>?
    private var devicesTask: Task<Void, Never>?

    private init() {
        observeRegistrationState()
        observeDevices()
    }

    // MARK: – Registration

    /// Opens Meta AI app to request glasses access.
    func startRegistration() {
        Task {
            do {
                try Wearables.shared.startRegistration()
            } catch {
                self.error = "Registration failed: \(error.localizedDescription)"
            }
        }
    }

    func stopRegistration() {
        Task {
            do {
                try Wearables.shared.startUnregistration()
            } catch {
                self.error = "Unregistration failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: – Camera permissions

    func checkAndRequestCameraPermission() async {
        let wearables = Wearables.shared
        do {
            cameraPermission = try await wearables.checkPermissionStatus(.camera)
            if cameraPermission != .granted {
                cameraPermission = try await wearables.requestPermission(.camera)
            }
        } catch {
            self.error = "Camera permission error: \(error.localizedDescription)"
        }
    }

    // MARK: – Camera stream

    func startStream() async {
        guard let device = connectedDevice else {
            error = "No device connected"
            return
        }
        await checkAndRequestCameraPermission()
        guard cameraPermission == .granted else {
            error = "Camera permission not granted"
            return
        }

        let wearables = Wearables.shared
        let selector = SpecificDeviceSelector(deviceId: device.id)
        // 15 fps, medium resolution (504×896) – good balance for AI analysis
        let config = StreamSessionConfig(frameRate: 15, resolution: .medium)
        let session = StreamSession(wearables: wearables, deviceSelector: selector, config: config)
        self.streamSession = session

        // Video frames
        frameToken = session.videoFramePublisher.listen { [weak self] frame in
            guard let image = frame.makeUIImage() else { return }
            Task { @MainActor [weak self] in
                self?.latestFrame = image
            }
        }

        // Photo data (for AI analysis)
        photoToken = session.photoDataPublisher.listen { [weak self] photoData in
            Task { @MainActor [weak self] in
                self?.latestPhoto = photoData.data
            }
        }

        // Stream state
        Task { [weak self] in
            for await state in await session.stateStream() {
                await MainActor.run { self?.streamState = state }
            }
        }

        await session.start()
    }

    func stopStream() {
        Task {
            await streamSession?.stop()
            streamSession = nil
            frameToken = nil
            photoToken = nil
        }
    }

    /// Triggers a JPEG photo capture from the glasses camera.
    func capturePhoto() {
        streamSession?.capturePhoto(format: .jpeg)
    }

    // MARK: – Private observers

    private func observeRegistrationState() {
        registrationTask = Task { [weak self] in
            let wearables = Wearables.shared
            for await state in wearables.registrationStateStream() {
                await MainActor.run {
                    self?.registrationState = state
                }
            }
        }
    }

    private func observeDevices() {
        devicesTask = Task { [weak self] in
            let wearables = Wearables.shared
            for await devices in wearables.devicesStream() {
                await MainActor.run {
                    self?.connectedDevice = devices.first
                }
            }
        }
    }
}
