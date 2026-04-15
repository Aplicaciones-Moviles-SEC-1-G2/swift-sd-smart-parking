# Juanes — Design Patterns
**Juan Esteban Jiménez · JuanesJB · SD Smart Parking**

---

## 1. Strategy Pattern — Biometric Authentication Paths

> Two interchangeable strategies to authenticate the user. The caller does not know which one runs; both satisfy the same goal: unlock the session.

**Files:** `AuthViewModel.swift` · `LoginView.swift` · `BiometricLockView.swift`

### Strategy A — `signInWithBiometrics()` (from the Login screen)

```swift
// AuthViewModel.swift — lines 176–208
func signInWithBiometrics() async {
    let context = LAContext()
    do {
        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Sign in to SD Parking"
        )
        if success {
            if let firebaseUser = Auth.auth().currentUser {
                await fetchUserData(uid: firebaseUser.uid)
            } else {
                #if DEBUG
                await MainActor.run { self.loginAsUser() }
                #endif
            }
        }
    } catch let error as LAError {
        await MainActor.run {
            switch error.code {
            case .userCancel, .systemCancel, .appCancel: break
            case .biometryNotEnrolled:
                self.errorMessage = "No biometrics enrolled. Use your password."
            case .biometryLockout:
                self.errorMessage = "Biometrics locked. Use your password."
            default:
                self.errorMessage = "Biometric authentication failed."
            }
        }
    }
}
```

### Strategy B — `authenticateWithBiometrics()` (from the Lock screen)

```swift
// AuthViewModel.swift — lines 212–258
func authenticateWithBiometrics() async {
    let context = LAContext()
    let reason = "Sign in to SD Parking"

    do {
        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
        if success {
            if let firebaseUser = Auth.auth().currentUser {
                await fetchUserData(uid: firebaseUser.uid)
            } else {
                #if DEBUG
                await MainActor.run {
                    if self._lastGerente { self.loginAsGerente() }
                    else { self.loginAsUser() }
                }
                #endif
            }
            await MainActor.run {
                self.requiresBiometricUnlock = false
                self.errorMessage = nil
            }
        }
    } catch let error as LAError {
        await MainActor.run {
            switch error.code {
            case .userCancel, .systemCancel, .appCancel: break
            case .biometryNotEnrolled:
                self.errorMessage = "No biometrics enrolled. Use your password instead."
            case .biometryLockout:
                self.errorMessage = "Biometrics locked. Use your password to unlock."
            default:
                self.errorMessage = "Biometric authentication failed."
            }
        }
    }
}
```

### Strategy selector — `biometricType` computed property

```swift
// AuthViewModel.swift — lines 27–34
var biometricType: LABiometryType {
    let ctx = LAContext()
    var error: NSError?
    guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        return .none
    }
    return ctx.biometryType   // .faceID | .touchID | .none
}
```

### Strategy consumer — `LoginView` (entry point A)

```swift
// LoginView.swift — lines 128–148
Button {
    Task { await authVM.signInWithBiometrics() }
} label: {
    HStack(spacing: 12) {
        Image(systemName: biometricIcon)
            .font(.system(size: 20))
        Text(biometricLabel)
            .font(.body)
            .fontWeight(.semibold)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .overlay(
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
    )
}
.foregroundColor(.blue)
.padding(.horizontal, 24)
```

### Strategy consumer — `BiometricLockView` (entry point B)

```swift
// BiometricLockView.swift — lines 48–58, 80–83
Button {
    Task { await authVM.authenticateWithBiometrics() }
} label: {
    Label(biometricLabel, systemImage: biometricIcon)
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .cornerRadius(15)
}
.padding(.horizontal, 40)

// Auto-triggers on screen appear:
.onAppear {
    Task { await authVM.authenticateWithBiometrics() }
}
```

---

## 2. Template Method Pattern — `signOut()` Soft vs Hard Logout

> `signOut()` defines a fixed skeleton: check biometrics → clear state → set flags.
> The two branches fill in the steps differently without changing the overall structure.

**File:** `AuthViewModel.swift`

```swift
// AuthViewModel.swift — lines 289–313
@MainActor
func signOut() {
    let ctx = LAContext()
    var err: NSError?
    let hasBiometrics = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)

    if hasBiometrics && biometricsEnabled {
        // ── Soft logout (Template variant A) ──────────────────────────────
        // Keep Firebase session alive so Face ID can restore the real user.
        _lastGerente = isGerente
        isLoggedIn = false
        requiresBiometricUnlock = true   // → shows BiometricLockView
        errorMessage = nil

    } else {
        // ── Hard logout (Template variant B) ──────────────────────────────
        // Fully destroy the session.
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        isLoggedIn = false
        isGerente = false
        currentUser = nil
        currentUserEmail = nil
        requiresBiometricUnlock = false
        errorMessage = nil
    }
}

// Role memory for biometric re-entry (used by soft logout only)
private var _lastGerente: Bool = false
```

---

## 3. Delegate Pattern — QR Scanner (AVFoundation)

> `AVCaptureMetadataOutputObjectsDelegate` — the system calls `metadataOutput(_:didOutput:from:)` each frame. The Coordinator reacts only when a valid QR is found and enforces a single-scan guard.

**File:** `QRScannerView.swift`

### Bridge (UIViewRepresentable) + Coordinator setup

```swift
// QRScannerView.swift — lines 11–25
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
}
```

### Coordinator — the Delegate

```swift
// QRScannerView.swift — lines 29–94
class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    let onScan: (String) -> Void
    let onError: (String) -> Void
    private var session: AVCaptureSession?
    private var hasScanned = false   // single-scan guard

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
        output.setMetadataObjectsDelegate(self, queue: .main)  // ← Delegate registration
        output.metadataObjectTypes = [.qr]

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    // ← Delegate method — called by AVFoundation each frame
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasScanned,                                      // single-scan gate
              let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        hasScanned = true
        session?.stopRunning()
        onScan(value)
    }
}
```

### Consumer — `SpotQRSheet`

```swift
// QRScannerView.swift — lines 156–163
QRScannerView(
    onScan: { value in handleScan(value) },
    onError: { msg in errorMessage = msg }
)
.clipShape(RoundedRectangle(cornerRadius: 20))
```

---

## 4. Observer Pattern (Write-path) — Real-Time Spot Sync

> Juanes wrote the **write** side of the Observer loop. When a spot is toggled, Firestore is updated; the existing snapshot listener (set up by Mateo) pushes the change to every subscribed view automatically.

**Files:** `SpotCard.swift` · `ParkingViewModel.swift`

### Trigger — `SpotCardView` (role-aware tap)

```swift
// SpotCard.swift — lines 52–68
.onTapGesture {
    if isGerente {
        // Admin: toggle any spot directly
        withAnimation(.spring()) {
            vm.reserveSpot(spot)
        }
    } else if spot.isAvailable {
        // Driver: open QR confirmation sheet
        showQRScanner = true
    }
}
.sheet(isPresented: $showQRScanner) {
    SpotQRSheet(spot: spot) {
        withAnimation(.spring()) {
            vm.reserveSpot(spot)
        }
    }
}
```

### Role-based UI labels

```swift
// SpotCard.swift — lines 37–45
if isGerente {
    Text(spot.isAvailable ? "Tap to occupy" : "Tap to free")
        .font(.system(size: 9))
        .foregroundColor(spot.isAvailable ? .green.opacity(0.8) : .red.opacity(0.8))
} else if spot.isAvailable {
    Label("Scan QR", systemImage: "qrcode.viewfinder")
        .font(.system(size: 9))
        .foregroundColor(.blue.opacity(0.7))
}
```

### Write-path — `updateSpotAvailability()` in `ParkingViewModel`

```swift
// ParkingViewModel.swift
func updateSpotAvailability(floor: Int, spotNumber: Int, available: Bool) async {
    let query = db.collection("parkingSpots")
        .whereField("floor", isEqualTo: floor)
        .whereField("number", isEqualTo: spotNumber)
        .limit(to: 1)

    let snapshot = try? await query.getDocuments()
    guard let doc = snapshot?.documents.first else { return }
    let ref = db.collection("parkingSpots").document(doc.documentID)
    try? await ref.updateData(["isAvailable": available])
    // ↑ Firestore write → snapshot listener fires → all views update
}
```

---

## 5. Facade Pattern — Weather Integration

> `WeatherViewModel` hides the raw HTTP request, JSON parsing, WMO code mapping, and error handling behind a single `fetchWeather()` call. Views just read `@Published var weather`.

**Files:** `WeatherViewModel.swift` · `SDNavigationView.swift`

### The Facade

```swift
// WeatherViewModel.swift — full file
struct WeatherData {
    let temperature: Double
    let weatherCode: Int

    var symbolName: String {
        switch weatherCode {
        case 0, 1:       return "sun.max.fill"
        case 2:          return "cloud.sun.fill"
        case 3:          return "cloud.fill"
        case 45, 48:     return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default:         return "cloud.fill"
        }
    }

    var symbolColor: Color {
        switch weatherCode {
        case 0, 1:       return .yellow
        case 2:          return .orange
        case 3, 45, 48:  return .gray
        case 51...65:    return .blue
        case 71, 73, 75: return .cyan
        case 80, 81, 82: return .blue
        case 95, 96, 99: return .purple
        default:         return .secondary
        }
    }
}

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var weather: WeatherData?
    @Published var isLoading = false

    // SD Building, Bogotá
    private let latitude  = 4.6014
    private let longitude = -74.0649

    init() { Task { await fetchWeather() } }

    func fetchWeather() async {
        isLoading = true
        defer { isLoading = false }

        let urlString = "https://api.open-meteo.com/v1/forecast" +
            "?latitude=\(latitude)&longitude=\(longitude)" +
            "&current=temperature_2m,weather_code"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let current = json["current"] as? [String: Any],
               let temp    = current["temperature_2m"] as? Double,
               let code    = current["weather_code"] as? Int {
                weather = WeatherData(temperature: temp, weatherCode: code)
            }
        } catch {
            print("Weather fetch error: \(error.localizedDescription)")
        }
    }
}
```

### Facade consumer — weather overlay in `SDNavigationView`

```swift
// SDNavigationView.swift — lines 72–92
private var weatherOverlay: some View {
    VStack {
        HStack {
            if let weather = weatherVM.weather {
                HStack(spacing: 6) {
                    Image(systemName: weather.symbolName)
                        .foregroundColor(weather.symbolColor)
                    Text("\(Int(weather.temperature))°C")
                        .font(.system(.subheadline, design: .rounded).bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)   // frosted glass pill
                .clipShape(Capsule())
            }
            Spacer()
        }
        Spacer()
    }
    .padding(12)
}
```

---

## Pattern Summary

| # | Pattern | File(s) | Key lines |
|---|---|---|---|
| 1 | **Strategy** — biometric paths | `AuthViewModel.swift`, `LoginView.swift`, `BiometricLockView.swift` | `signInWithBiometrics()` vs `authenticateWithBiometrics()` |
| 2 | **Template Method** — soft/hard logout | `AuthViewModel.swift` | `signOut()` two branches |
| 3 | **Delegate** — QR AVFoundation | `QRScannerView.swift` | `metadataOutput(_:didOutput:from:)` |
| 4 | **Observer** (write-path) — spot sync | `SpotCard.swift`, `ParkingViewModel.swift` | `updateSpotAvailability()` → Firestore → listener |
| 5 | **Facade** — weather | `WeatherViewModel.swift`, `SDNavigationView.swift` | `fetchWeather()` hides HTTP + JSON + WMO mapping |
