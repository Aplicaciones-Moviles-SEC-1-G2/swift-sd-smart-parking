# SD Smart Parking — iOS App

An iOS application for real-time smart parking management. The system supports two roles: **Gerente** (parking manager) and **Usuario** (driver), each with a dedicated experience.

---

## Features

### Usuario (Driver)
- View real-time parking spot availability by floor
- Navigate to the parking building via Google Maps or Apple Maps
- Manage registered vehicles (plates)
- Edit personal profile

### Gerente (Manager)
- Dashboard with occupancy summary
- Create vehicle entry/exit records with OCR confidence scoring
- Manage and visualize parking spots by floor
- Generate and view usage reports
- Configure parking settings

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.0 |
| UI | SwiftUI |
| Auth | Firebase Authentication + Google Sign-In |
| Database | Firebase Firestore |
| Storage | Firebase Storage |
| Maps | Google Maps SDK + MapKit |
| Location | CoreLocation |
| Min iOS | 26.2 |

---

## Project Structure

```
sd-smart-parking/
├── Core/
│   ├── GerenteTabView.swift       # Manager tab navigation
│   ├── UsuarioTabView.swift        # User tab navigation
│   └── ParkingConfig.swift         # Parking configuration
├── Models/
│   ├── User.swift
│   ├── Car.swift
│   ├── ParkingSpot.swift
│   └── VehicleRecord.swift
├── ViewModels/
│   ├── AuthViewModel.swift         # Login, registration, role detection
│   └── ParkingViewModel.swift      # Spot state management
├── Views/
│   ├── Login/                      # LoginView, RegistrationView
│   ├── Parking/                    # SpotsView, SpotCard
│   ├── Gerente/                    # Dashboard, records, reports
│   ├── Usuario/                    # Profile, cars, navigation
│   └── Components/                 # Shared UI components
├── Location/
│   └── NavigationManager.swift     # CLLocationManager + ETA calculation
├── GoogleService-Info.plist        # Firebase config
└── Info.plist                      # App config (Google Sign-In URL scheme)
```

---

## Getting Started

### Prerequisites

- Xcode 16 or later
- An Apple developer account (for simulator runs, a free account works)
- Firebase project with Authentication and Firestore enabled
- Google Maps SDK API key

### Setup

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd swift-sd-smart-parking
   ```

2. **Open the project**
   ```bash
   open sd-smart-parking/sd-smart-parking.xcodeproj
   ```

3. **Resolve Swift packages**
   Xcode will automatically resolve all SPM dependencies on first open (Firebase, Google Sign-In, Google Maps).

4. **Configure Firebase**
   Replace `sd-smart-parking/GoogleService-Info.plist` with your own from the Firebase console. Make sure **Authentication** (email/password + Google) and **Firestore** are enabled.

5. **Configure Google Sign-In**
   In `Info.plist`, update `GIDClientID` and the `CFBundleURLSchemes` value to match your Google OAuth client ID.

6. **Run**
   Select an iPhone simulator (iOS 26.2+) and press `⌘R`.

---

## Architecture

The app uses an **MVVM** pattern built on SwiftUI and Combine.

- `AuthViewModel` handles Firebase Auth state and exposes the current user role (`Gerente` / `Usuario`) to `ContentView`, which routes to the appropriate tab view.
- `ParkingViewModel` manages parking spot state and communicates with Firestore.
- Views are stateless and driven entirely by `@ObservableObject` / `@StateObject` bindings.

---

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for branch naming, commit conventions, PR process, and code style guidelines.
