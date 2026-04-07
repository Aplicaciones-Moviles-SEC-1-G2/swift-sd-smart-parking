import SwiftUI

// MARK: - Agregar en ParkingViewModel
// func addRecord(_ record: VehicleRecord) {
//     vehicleRecords.insert(record, at: 0)
// }

struct CreateRecordView: View {
    @EnvironmentObject var vm: ParkingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var plate: String = ""
    @State private var recordType: RecordType = .entry
    @State private var floor: Int = 1
    @State private var spotNumber: Int = 1
    @State private var isRegistered: Bool = true
    @State private var ownerEmail: String = ""
    @State private var ocrConfidence: Double = 1.0
    @State private var showConfirmation: Bool = false

    var isFormValid: Bool {
        plate.trimmingCharacters(in: .whitespaces).count >= 3
    }

    var body: some View {
        NavigationStack {
            List {

                // MARK: - Plate
                Section {
                    HStack {
                        TextField("e.g. ABC123", text: $plate)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(size: 22, weight: .bold))
                    }
                } header: {
                    Label("License Plate", systemImage: "rectangle.fill")
                } footer: {
                    if !plate.isEmpty && plate.count < 3 {
                        Text("Plate must be at least 3 characters.")
                            .foregroundColor(.red)
                    }
                }

                // MARK: - Record Type
                Section {
                    Picker("Type", selection: $recordType) {
                        Label("Entry", systemImage: "arrow.down.circle.fill")
                            .tag(RecordType.entry)
                        //Label("Exit", systemImage: "arrow.up.circle.fill")
                            //.tag(RecordType.exit)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                } header: {
                    Label("Record Type", systemImage: "arrow.up.arrow.down")
                }

                // MARK: - Location
                Section {
                    Stepper("Floor: \(floor)", value: $floor, in: 1...10)
                    Stepper("Spot: \(spotNumber)", value: $spotNumber, in: 1...100)
                } header: {
                    Label("Location", systemImage: "mappin.circle.fill")
                }

                // MARK: - Owner
                /*
                Section {
                    Toggle("Registered Vehicle", isOn: $isRegistered)

                    if isRegistered {
                        LabeledContent("Owner Email") {
                            TextField("email@example.com", text: $ownerEmail)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                    }
                } header: {
                    Label("Owner", systemImage: "person.fill")
                }
                */
                // MARK: - OCR Confidence
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Confidence")
                            Spacer()
                            Text("\(Int(ocrConfidence * 100))%")
                                .foregroundColor(ocrConfidence < 0.75 ? .orange : .secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $ocrConfidence, in: 0.5...1.0, step: 0.05)
                            .tint(ocrConfidence < 0.75 ? .orange : .blue)
                    }

                    if ocrConfidence < 0.75 {
                        Label("This record will be flagged for review.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } header: {
                    Label("OCR Confidence", systemImage: "camera.fill")
                }
            }
            .navigationTitle("New Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                //ToolbarItem(placement: .navigationBarLeading) {
                    //Button("Cancel") { dismiss() }
                //}
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRecord()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .alert("Record Saved", isPresented: $showConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text("The record for plate \(plate.uppercased()) was created successfully.")
            }
        }
    }

    // MARK: - Save
    private func saveRecord() {
        let record = VehicleRecord(
            id: nil,
            plate: plate.uppercased().trimmingCharacters(in: .whitespaces),
            type: recordType,
            timestamp: .now,
            floor: floor,
            spotNumber: spotNumber,
            photoURL: nil,
            isRegistered: isRegistered,
            ownerEmail: isRegistered && !ownerEmail.isEmpty ? ownerEmail : nil,
            ocrConfidence: ocrConfidence
        )
        vm.addRecord(record)
        showConfirmation = true
    }
}

#Preview {
    CreateRecordView()
        .environmentObject(ParkingViewModel())
}
