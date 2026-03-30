// CameraPreviewView.swift
// Oldies
//
// Displays the live video stream from Meta Ray-Ban glasses.
// Used optionally in the assistant screen or as a standalone preview.
// Frames are delivered by GlassesManager via @Published latestFrame.

import SwiftUI

struct CameraPreviewView: View {

    @EnvironmentObject private var glasses: GlassesManager

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let frame = glasses.latestFrame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.1), value: frame)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Ingen kameraström")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                    if glasses.connectedDevice != nil && glasses.streamState != .streaming {
                        Button {
                            Task { await glasses.startStream() }
                        } label: {
                            Label("Starta ström", systemImage: "play.circle.fill")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Overlay: stream resolution / fps badge
            if glasses.streamState == .streaming {
                VStack {
                    HStack {
                        Spacer()
                        Text("LIVE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.red)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .padding()
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("Kamera")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    CameraPreviewView()
        .environmentObject(GlassesManager.shared)
}
