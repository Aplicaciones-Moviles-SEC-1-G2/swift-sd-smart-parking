//
//  PlateOCRScannerView.swift
//  sd-smart-parking
//

import AVFoundation
import SwiftUI
import Vision

// MARK: - UIKit camera view for plate OCR

struct PlateOCRCameraView: UIViewRepresentable {
    let onPlateRecognized: (String, Float) -> Void
    let onError: (String) -> Void
    @Binding var captureRequested: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onPlateRecognized: onPlateRecognized, onError: onError)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        context.coordinator.configure(view: view)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if captureRequested {
            context.coordinator.capturePhoto()
            DispatchQueue.main.async { captureRequested = false }
        }
    }

    // MARK: - Coordinator (AVCapturePhotoCaptureDelegate)

    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        let onPlateRecognized: (String, Float) -> Void
        let onError: (String) -> Void
        private var session: AVCaptureSession?
        private var photoOutput: AVCapturePhotoOutput?

        // Sprint 4 micro-optimization: a single VNRecognizeTextRequest is
        // reused across captures instead of allocating + configuring a fresh
        // one per photo. The completion handler is wired at init (Vision marks
        // the property get-only after construction) and dispatches to the
        // stored `onPlateRecognized` / `onError` callbacks, which don't change
        // across the coordinator's lifetime.
        private lazy var recognizeTextRequest: VNRecognizeTextRequest = {
            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self else { return }

                if let error {
                    DispatchQueue.main.async { self.onError(error.localizedDescription) }
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async { self.onError("No text found in image.") }
                    return
                }

                let candidates: [(text: String, confidence: Float)] = observations.compactMap { obs in
                    guard let top = obs.topCandidates(1).first else { return nil }
                    return (text: top.string, confidence: top.confidence)
                }

                DispatchQueue.main.async {
                    if let match = findColombianPlate(in: candidates) {
                        self.onPlateRecognized(match.plate, match.confidence)
                    } else {
                        self.onError("No valid license plate found. Try again.")
                    }
                }
            }
            request.recognitionLevel = .accurate
            return request
        }()

        init(
            onPlateRecognized: @escaping (String, Float) -> Void,
            onError: @escaping (String) -> Void
        ) {
            self.onPlateRecognized = onPlateRecognized
            self.onError = onError
        }

        func configure(view: PreviewView) {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                startSession(view: view)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            self?.startSession(view: view)
                        } else {
                            self?.onError("Camera access denied.")
                        }
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
                let input = try? AVCaptureDeviceInput(device: device)
            else {
                onError("Could not access the camera.")
                return
            }
            session.addInput(input)

            let output = AVCapturePhotoOutput()
            session.addOutput(output)
            self.photoOutput = output

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

        func capturePhoto() {
            guard let photoOutput else { return }
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        func photoOutput(
            _ output: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            if let error {
                DispatchQueue.main.async { self.onError(error.localizedDescription) }
                return
            }

            guard let cgImage = photo.cgImageRepresentation() else {
                DispatchQueue.main.async { self.onError("Could not process the captured image.") }
                return
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([recognizeTextRequest])
            } catch {
                DispatchQueue.main.async { self.onError(error.localizedDescription) }
            }
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

// MARK: - Sheet for plate OCR scanning

struct PlateOCRSheet: View {
    let onPlateScanned: (String, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var state: PlateOCRState = .scanning
    @State private var captureRequested: Bool = false

    private enum PlateOCRState {
        case scanning
        case processing
        case recognized(plate: String, confidence: Float)
        case error(String)
    }

    private var isScanning: Bool {
        switch state {
        case .scanning, .processing: return true
        default: return false
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isScanning {
                    cameraView
                }

                switch state {
                case .scanning, .processing:
                    EmptyView()  // camera + overlay handled above
                case .recognized(let plate, let confidence):
                    recognizedView(plate: plate, confidence: confidence)
                case .error(let message):
                    errorView(message: message)
                }

                Spacer()
            }
            .navigationTitle("Scan License Plate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - State views

    /// Camera stays mounted during both `.scanning` and `.processing` so the
    /// coordinator survives long enough to finish the capture + Vision pipeline.
    private var cameraView: some View {
        VStack(spacing: 16) {
            Text("Point the camera at the license plate.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top)

            ZStack {
                PlateOCRCameraView(
                    onPlateRecognized: { plate, confidence in
                        state = .recognized(plate: plate, confidence: confidence)
                    },
                    onError: { message in
                        state = .error(message)
                    },
                    captureRequested: $captureRequested
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                )

                if case .processing = state {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                    ProgressView("Recognizing plate...")
                }
            }
            .frame(height: 320)
            .padding(.horizontal)

            Button {
                state = .processing
                captureRequested = true
            } label: {
                Label("Capture", systemImage: "camera.shutter.button")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(
                {
                    if case .processing = state { return true }
                    return false
                }())
        }
    }

    private func recognizedView(plate: String, confidence: Float) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text(plate)
                .font(.system(size: 40, weight: .bold, design: .monospaced))

            HStack(spacing: 16) {
                Button("Rescan") {
                    state = .scanning
                }
                .buttonStyle(.bordered)

                Button("Use Plate") {
                    onPlateScanned(plate, Double(confidence))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)

            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                state = .scanning
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }
}
