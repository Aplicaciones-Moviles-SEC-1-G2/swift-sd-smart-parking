//
//  VehicleAIScannerView.swift
//  sd-smart-parking
//
//  Camera sheet that captures a car photo and runs Gemini to identify
//  plate, color, brand, and model.
//

import SwiftUI
import UIKit

// MARK: - Sheet

struct VehicleAIScannerSheet: View {
    let onUseResult: (VehicleIdentification) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @StateObject private var vm = VehicleAIScannerViewModel()
    @State private var capturedImage: UIImage? = nil
    @State private var showPicker: Bool = true
    @State private var showPlateOCRFallback: Bool = false
    @State private var showHistory: Bool = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("AI Vehicle Scan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showHistory = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                }
                .sheet(isPresented: $showHistory) {
                    ScanHistorySheet()
                }
                .sheet(isPresented: $showPicker) {
                    CameraImagePicker { image in
                        capturedImage = image
                        showPicker = false
                        guard let image else {
                            dismiss()
                            return
                        }
                        if networkMonitor.isConnected {
                            vm.analyze(image: image)
                        } else {
                            showPlateOCRFallback = true
                        }
                    }
                    .ignoresSafeArea()
                }
                .sheet(isPresented: $showPlateOCRFallback) {
                    PlateOCRSheet { plate, _ in
                        let identification = VehicleIdentification(
                            plate: plate,
                            plateVisible: true,
                            color: "unknown",
                            brand: "unknown",
                            model: "unknown"
                        )
                        onUseResult(identification)
                        // Symmetric cleanup before dismiss — keeps the
                        // showPlateOCRFallback state from reactivating if
                        // the parent re-presents this sheet later.
                        showPlateOCRFallback = false
                        dismiss()
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.top)
                }

                switch vm.state {
                case .idle:
                    if !networkMonitor.isConnected {
                        OfflineNoticeBadge(message: "Sin conexión — usaremos OCR local")
                            .padding(.top, 12)
                    }
                    Text("Take a photo of the vehicle to analyze it.")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                case .analyzing:
                    analyzingView
                case .success(let identification):
                    resultsView(identification)
                case .failure(let message):
                    errorView(message)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - State views

    private var analyzingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Analyzing with Gemini...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func resultsView(_ id: VehicleIdentification) -> some View {
        VStack(spacing: 16) {
            if id.hasPlate {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Plate detected")
                        .font(.subheadline).bold()
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("No plate visible")
                        .font(.subheadline).bold()
                        .foregroundColor(.orange)
                }
            }

            VStack(spacing: 0) {
                resultRow(label: "Plate",
                          value: id.hasPlate ? (id.plate ?? "—") : "not visible",
                          monospaced: id.hasPlate,
                          valueColor: id.hasPlate ? .primary : .orange)
                Divider()
                resultRow(label: "Color", value: id.color.capitalized)
                Divider()
                resultRow(label: "Brand", value: id.brand.capitalized)
                Divider()
                resultRow(label: "Model", value: id.model.capitalized)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button("Retake") {
                    capturedImage = nil
                    vm.reset()
                    showPicker = true
                }
                .buttonStyle(.bordered)

                Button("Use Result") {
                    onUseResult(id)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding(.bottom)
    }

    private func resultRow(label: String,
                           value: String,
                           monospaced: Bool = false,
                           valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced).bold() : .body)
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            if !networkMonitor.isConnected {
                OfflineNoticeBadge(message: "Sin conexión — usa el OCR local")
            }

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Try Again") {
                    capturedImage = nil
                    vm.reset()
                    showPicker = true
                }
                .buttonStyle(.bordered)

                if !networkMonitor.isConnected {
                    Button("Use local OCR") {
                        showPlateOCRFallback = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.large)
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Camera picker bridge

struct CameraImagePicker: UIViewControllerRepresentable {
    let onPicked: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (UIImage?) -> Void

        init(onPicked: @escaping (UIImage?) -> Void) {
            self.onPicked = onPicked
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onPicked(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onPicked(nil)
        }
    }
}
