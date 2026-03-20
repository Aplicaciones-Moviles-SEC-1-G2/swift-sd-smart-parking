//
//  QRScannerView.swift
//  sd-smart-parking
//

import SwiftUI
import AVFoundation

// MARK: - UIKit camera view wrapped for SwiftUI

struct QRScannerView: UIViewRepresentable {
    let onScan: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onError: onError)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        context.coordinator.configure(view: view)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    // MARK: - Coordinator (AVFoundation delegate)

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScan: (String) -> Void
        let onError: (String) -> Void
        private var session: AVCaptureSession?
        private var hasScanned = false

        init(onScan: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onScan = onScan
            self.onError = onError
        }

        func configure(view: PreviewView) {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                startSession(view: view)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted { self?.startSession(view: view) }
                        else { self?.onError("Camera access denied.") }
                    }
                }
            default:
                onError("Camera access is not allowed. Enable it in Settings.")
            }
        }

        private func startSession(view: PreviewView) {
            let session = AVCaptureSession()
            self.session = session

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                onError("Could not access the camera.")
                return
            }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            DispatchQueue.main.async {
                let preview = AVCaptureVideoPreviewLayer(session: session)
                preview.videoGravity = .resizeAspectFill
                view.previewLayer = preview
                view.layer.insertSublayer(preview, at: 0)
                preview.frame = view.bounds
            }

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !hasScanned,
                  let obj = objects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            hasScanned = true
            session?.stopRunning()
            onScan(value)
        }
    }

    // MARK: - UIView that hosts the preview layer

    class PreviewView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            didSet { previewLayer?.frame = bounds }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}

// MARK: - Sheet shown when a user taps an available spot

struct SpotQRSheet: View {
    let spot: ParkingSpot
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scanResult: String? = nil
    @State private var errorMessage: String? = nil
    @State private var confirmed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Spot info header
                VStack(spacing: 6) {
                    Text("Spot \(spot.number) — Floor \(spot.floor)")
                        .font(.title2.bold())
                    Text("Scan the QR code at the parking spot to confirm your reservation.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                if confirmed {
                    // Success state
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                        Text("Spot Reserved!")
                            .font(.title.bold())
                        Text("You have reserved spot \(spot.number) on floor \(spot.floor).")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    // Scanner
                    ZStack {
                        QRScannerView(
                            onScan: { value in
                                handleScan(value)
                            },
                            onError: { msg in
                                errorMessage = msg
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                        // Viewfinder overlay
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.6), lineWidth: 2)

                        VStack {
                            Spacer()
                            Text("Point the camera at the QR code")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Capsule())
                                .padding(.bottom, 16)
                        }
                    }
                    .frame(height: 320)
                    .padding(.horizontal)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }

                Spacer()
            }
            .navigationTitle("Confirm Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func handleScan(_ value: String) {
        // Accept any QR that contains the spot number, or any valid QR string
        let expectedCode = "SPOT-\(spot.number)"
        if value == expectedCode || !value.isEmpty {
            withAnimation {
                confirmed = true
            }
            onConfirm()
        } else {
            errorMessage = "Invalid QR code. Please scan the code at spot \(spot.number)."
        }
    }
}
