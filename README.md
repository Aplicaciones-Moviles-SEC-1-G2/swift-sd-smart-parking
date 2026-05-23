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

---

## Sprint Tracking — Juan Esteban Jiménez (JuanesJB)

### 📋 Sprint 4 (May 2026)

| Resource | Link |
|---|---|
| 🗂 Project board | [Sprint 4 — Juanes](https://github.com/orgs/Aplicaciones-Moviles-SEC-1-G2/projects/2) |
| 🏁 Milestone | [Sprint 4](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/milestone/3) |
| 🔀 Main PR | [#71 feat(sprint4/juanes): analytics views, multi-threading, caching, eventual connectivity & BQs](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/pull/71) |
| 🐛 All issues | [Issues — label: sprint-4 + juanes](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues?q=label%3Asprint-4+label%3Ajuanes) |

**Issues entregados (13):**

| # | Feature | Labels |
|---|---|---|
| [#79](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/79) | Micro-optimization — `floorAvailability` O(n)→O(1), 25%→8% CPU (Principle #1) | `micro-optimization` `performance` |
| [#72](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/72) | Multi-threading — Swift actor + `async let` ×5 + `withTaskGroup` | `concurrency` |
| [#73](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/73) | Two-layer caching — NSCache L1 + KeyValueStore L2 | `caching` |
| [#82](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/82) | `KeyValueStore<K,V>` — generic thread-safe JSON disk store | `caching` |
| [#74](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/74) | Eventual connectivity — offline-first analytics with cached fallback | `connectivity` |
| [#83](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/83) | `NetworkMonitor` — `@MainActor` NWPathMonitor singleton | `connectivity` |
| [#84](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/84) | `PendingActionsQueue` — offline write buffer + drain-on-reconnect | `connectivity` |
| [#81](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/81) | `PersonalStatsView` — `async let` ×5 concurrent aggregation + weekday chart | `analytics` `concurrency` |
| [#80](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/80) | `FloorMonitorView` — `withTaskGroup` per-floor + starred floors persistence | `analytics` `caching` |
| [#76](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/76) | `MyHistoryView` — Swift actor session processing + grouped history | `analytics` |
| [#75](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/75) | `CostBreakdownView` — monthly spend, cap-hit rate, cost-by-floor | `analytics` |
| [#77](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/77) | BQ-WEEKDAY · BQ-SESSIONS · BQ-MONTHLY (Sprint 4 business questions) | `analytics` |
| [#85](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/85) | `analytics-dashboard-UN.html` — unified real-time Firebase BQ dashboard | `analytics` |

---

### 📋 Sprint 3 (April 2026)

| Resource | Link |
|---|---|
| 🏁 Milestone | [Sprint 3](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/milestone/2) |
| 🔀 Main PR | [#38 feat(sprint3): caching, concurrency, local storage, eventual connectivity & BQ-ORG](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/pull/38) |
| 🐛 All issues | [Issues — label: sprint-3 + juanes](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues?q=label%3Asprint-3+label%3Ajuanes) |

**Issues entregados (5):**

| # | Feature | Labels |
|---|---|---|
| [#39](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/39) | `SpotCacheManager` — NSCache for parking spots (countLimit 500, costLimit 2 MB) | `caching` |
| [#40](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/40) | `withTaskGroup` concurrency — parallel initial Firestore data load | `concurrency` |
| [#41](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/41) | `PendingActionsQueue` v1 — FileManager JSON offline action queue | `connectivity` |
| [#42](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/42) | NWPathMonitor eventual connectivity — 5 protected views + orange banner | `connectivity` |
| [#43](https://github.com/Aplicaciones-Moviles-SEC-1-G2/swift-sd-smart-parking/issues/43) | BQ-ORG — organization clients analytics (Uniandes vs visitors) | `analytics` |


## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for branch naming, commit conventions, PR process, and code style guidelines.
