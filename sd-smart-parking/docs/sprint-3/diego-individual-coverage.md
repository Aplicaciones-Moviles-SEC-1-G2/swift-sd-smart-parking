---
sprint: 3
scope: Cobertura individual del rubric — Diego Benavides (criterios 4, 5, 6 + defensa de 3)
audience: Diego (planeación + ejecución) y evaluador (defensa oral)
generated: 2026-05-05
authority: az4diegoz@gmail.com / 112740010+db-unicode@users.noreply.github.com
---

# Sprint 3 — Cobertura individual del rubric (Diego)

> **Doc maestro.** Único archivo necesario para ejecutar todo Sprint 3 individual de Diego. Contiene el plan de las 11 features, los archivos exactos a tocar, las decisiones técnicas defendibles, las pruebas, la verificación end-to-end y la crib de defensa oral.
>
> **Plan completo (con discusión y trade-offs):** `~/.claude/plans/basado-en-docs-analysis-sprint-3-rubric-vivid-teacup.md`.
> **Análisis previo (qué tiene Diego hoy):** [`docs/analysis/sprint-3-rubric-coverage.md`](../analysis/sprint-3-rubric-coverage.md).

---

## 0. Resumen ejecutivo

| Criterio | Actual | Plan suma | Después | Estrategia |
|---|---|---|---|---|
| 3. Multithreading / Async | 20 / 20 ✅ | 0 | 20 / 20 | Sólo crib oral (PRs #20/#21/#22/#37 ya cubren las 4 estrategias) |
| 4. Local Storage | 0 / 20 | 25 declarables (cap 20) | **20 / 20** | SwiftData + Codable file + Keychain + @AppStorage + KeyValueStore |
| 5. Eventual Connectivity | 0 / 20 | 4 vistas con guarda explícita | **20 / 20** | Guardas `NetworkMonitor` en 4 vistas Diego |
| 6. Caching | 0 / 20 | NSCache + LRU | **20 / 20** | NSCache propio (10) + LRU manual (10) |
| **Total** | **20 / 80** | — | **80 / 80** | 11 features ortogonales al código de Mateo/Juanes |

**Por qué redundancia en criterio 4:** la rúbrica suma a 25 pts (10+5+5+5) pero capa a 20. Implementamos las 4 estrategias **+1 extra (Keychain)** para que ningún rechazo individual quite los 20.

---

## 1. Hallazgos clave del código (referencia rápida)

Estos hallazgos vienen de la exploración previa. Los anclamos aquí para no tener que volver a buscarlos durante la ejecución.

- **Test target ya existe:** `sd-smart-parkingTests/` con 9 archivos `*Tests.swift` (incluidos los de Diego: `CalendarExportViewModelTests`, `TripPlannerViewModelTests`, `AuthViewModelMicrosoftTests`, `PersonalizedRecommendationTests`, `ParkingDemandInsightsTests`, `HistoricDemandScheduleTests`, `ParkingTimeStatusTests`, `ColombianPlateValidatorTests`). No hay setup de cero — añadimos pruebas ahí.
- **`NetworkMonitor` ya está inyectado globalmente** vía `.environmentObject(networkMonitor)` en `sd-smart-parking/sd_smart_parkingApp.swift:29` (`@StateObject` en línea 22). Las vistas de Diego sólo necesitan `@EnvironmentObject var networkMonitor: NetworkMonitor`.
- **`SwiftData` no se importa en ningún lugar** del proyecto. `Security` framework tampoco. iOS 26.0 + Swift 5.0 + `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` confirmados en `project.pbxproj`. SwiftData requiere iOS 17+ (cubierto).
- **`VehicleAIScannerViewModel` es `@MainActor`** (`sd-smart-parking/ViewModels/VehicleAIScannerViewModel.swift:12`). Punto natural de inserción del NSCache: justo antes de `model.generateContent(prepared, Self.prompt)` en línea 51, con write tras `state = .success(identification)` en línea 57.
- **`TripPlannerViewModel` NO es `@MainActor`** a nivel de clase y usa `await MainActor.run { ... }` para mutar `@Published` (líneas 139, 151, 159). El LRU cache vive como propiedad de instancia `private let costCache = LRUCache<TripCacheKey, Double>(capacity: 5)` sin tocar concurrencia.
- **Banners offline existentes (NO TOCAR):** `Views/Parking/SpotsView.swift:44-61` (Juanes), `Views/Usuario/Dashboard/DashboardView.swift:43-67` (Juanes), `Views/Gerente/GerenteSummaryView.swift:59-72` (Juanes). Diego añade banners/guards SÓLO en sus propias vistas, con un componente nuevo (`OfflineNoticeBadge`) deliberadamente diferente.
- **`PlateOCRSheet`** (`Views/Gerente/PlateOCRScannerView.swift:164`) acepta `onPlateScanned: (String, Double) -> Void` y funciona 100% offline (Vision on-device). Es el fallback ideal para `VehicleAIScannerSheet`.
- **`ParkingDemandInsightsView`** (`Views/Usuario/Dashboard/ParkingDemandInsightsView.swift:12`) recibe `records: [VehicleRecord]` por init. No hay timestamp de sync; usaremos `vm.vehicleRecords.first?.timestamp` como proxy desde el call site.
- **`LoginView`** (`Views/Login/LoginView.swift:11`) sólo importa `@EnvironmentObject var authVM: AuthViewModel`. Botones de red en líneas 73-90 (email), 101-125 (Google, NO de Diego), **128-152 (Microsoft, de Diego)**, 155-175 (biometrics local). Sólo modificamos el bloque Microsoft.

---

## 2. Archivos NO TOCAR (autoría de Mateo / Juanes)

`git blame` confirma autoría ajena. Modificarlos rompe la trazabilidad individual. **Sólo lectura.**

### Persistence stack (Mateo / Juanes)
- `Core/SpotCacheManager.swift` (Juanes — NSCache para spots)
- `Core/PendingActionsQueue.swift` (Juanes/Mateo — cola offline)
- `FileManagers/DiskPersistanceManager.swift` (Mateo — Codable+FileManager genérico)
- `FileManagers/ArrayMap.swift` (Mateo — k/v sorted parallel arrays)
- `FileManagers/PendingAction.swift` (Mateo; Diego sólo añadió `case .updatePreferences`)
- `FileManagers/SyncQueueModels.swift` (Mateo)
- `Repositories/UserRepository.swift` (Mateo)
- `Location/NavigationManager.swift` (compañeros)

### Banners offline (Juanes)
- `Views/Parking/SpotsView.swift:44-61`
- `Views/Usuario/Dashboard/DashboardView.swift:43-67` *(excepción:* 1 línea del call site para PR-B.3, `lastSyncedAt: vm.vehicleRecords.first?.timestamp`*)*
- `Views/Gerente/GerenteSummaryView.swift:59-72`
- `Views/Usuario/ActiveInfo/MyHistoryView.swift:45`

### UserDefaults / @AppStorage (Juanes)
- `@AppStorage("biometricsEnabled")` en `AuthViewModel.swift:38`
- **Regla:** Diego usa SIEMPRE prefijo `diego.*` en sus llaves nuevas (`diego.tripPlanner.preferredCurrency`, `diego.profile.showDemandBadgeOnDashboard`, etc.) para que `git blame` no las confunda.

### LoginView — sólo modificamos el bloque del botón Microsoft
- Email (líneas 73-90), Google (101-125), Biometrics (155-175): **NO TOCAR**.
- Microsoft (128-152) + caption justo debajo: ✅ Diego.

---

## 3. PR-A — Pre-requisitos compartidos (infra Diego)

Foundation común que reusan PR-B y los demás. Crearlos primero porque desbloquean unit-testing y reduce duplicación visual.

### 3.1 `Core/NetworkConditionsProviding.swift` (NUEVO)

```swift
//
//  NetworkConditionsProviding.swift
//  sd-smart-parking
//
//  Permite inyectar el estado de red en VMs/vistas y mockearlo en tests
//  sin acoplar al NetworkMonitor concreto del compañero. NetworkMonitor
//  conforma vía extension; mocks proveen su propia implementación.
//

import Combine

protocol NetworkConditionsProviding: AnyObject {
    var isConnected: Bool { get }
}

extension NetworkMonitor: NetworkConditionsProviding {}
```

Mock para tests (en `sd-smart-parkingTests/Helpers/MockNetworkConditions.swift`, se crea cuando llegue PR-B):
```swift
final class MockNetworkConditions: NetworkConditionsProviding {
    var isConnected: Bool
    init(isConnected: Bool = true) { self.isConnected = isConnected }
}
```

### 3.2 `Views/Components/OfflineNoticeBadge.swift` (NUEVO)

Pill discreto azul-claro, **deliberadamente diferente** al banner naranja de Juanes (capsule vs banner full-width).

```swift
//
//  OfflineNoticeBadge.swift
//  sd-smart-parking
//
//  Pill informativo que Diego usa en sus vistas para indicar estado offline.
//  Estilo distinto al banner naranja de Juanes para que git blame deje
//  autoría visualmente clara.
//

import SwiftUI

struct OfflineNoticeBadge: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.12))
        .foregroundColor(.blue)
        .clipShape(Capsule())
    }
}

#Preview {
    OfflineNoticeBadge(message: "Sin conexión — modo limitado")
        .padding()
}
```

**Tests:** ninguno necesario (componente puro de presentación; se valida visualmente en cada PR-B.x).

---

## 4. PR-B — Eventual Connectivity (criterio 5, 20 pts)

Las 4 vistas de Diego reciben `@EnvironmentObject var networkMonitor: NetworkMonitor` y muestran `OfflineNoticeBadge` cuando `!isConnected`.

### 4.1 PR-B.1 — VehicleAI Scanner: fallback a OCR local *(5 pts)*

**Archivo:** `Views/Gerente/VehicleAIScannerView.swift` (autoría Diego, PR #37).

**Cambios:**
1. Añadir `@EnvironmentObject var networkMonitor: NetworkMonitor` después de `@StateObject private var vm` (línea 18).
2. Añadir `@State private var showPlateOCRFallback: Bool = false`.
3. Modificar el handler `.sheet(isPresented: $showPicker)` (líneas 32-43): si `!networkMonitor.isConnected`, en vez de `vm.analyze(image:)`, setear `showPlateOCRFallback = true`.
4. Añadir nuevo `.sheet(isPresented: $showPlateOCRFallback)` que presenta `PlateOCRSheet`. Cuando OCR detecta placa, construir un `VehicleIdentification(plate: plate, plateVisible: true, color: "unknown", brand: "unknown", model: "unknown")` y llamar `onUseResult(...)` + `dismiss()`.
5. En el `content` ViewBuilder, cuando `case .idle` y `!networkMonitor.isConnected`, mostrar `OfflineNoticeBadge(message: "Sin conexión — usaremos OCR local")` arriba del texto "Take a photo of the vehicle...".

**Tests:** snapshot UI manual (XCUITest opcional). Ver § 8.

**Defensa oral:** *"Cuando hay red usamos Gemini para extraer marca/modelo/color/placa. Cuando no hay red, caemos a Vision (PlateOCR on-device, también mío) que al menos extrae la placa. Es un fallback determinista visible al usuario, no degradación silenciosa."*

---

### 4.2 PR-B.2 — Trip Planner: badge offline *(5 pts)*

**Archivo:** `Views/Usuario/Dashboard/TripPlannerSheetView.swift` (autoría Diego, PR #21).

**Cambios:**
1. Añadir `@EnvironmentObject var networkMonitor: NetworkMonitor` después de la línea 11 (`@Environment(\.dismiss)`).
2. En la sección "Estimated Cost" (líneas 48-66), debajo del HStack del precio, si `!networkMonitor.isConnected` mostrar `OfflineNoticeBadge(message: "Sin conexión — el costo y exportar a Calendar siguen funcionando")`.
3. Botón "Add to Calendar" sigue habilitado (EventKit es 100% local).

**Tests:** unit test en `TripPlannerViewModelTests.swift` no aplica (es UI). Verificación manual con simulator offline.

**Defensa oral:** *"Trip Planner es 100% local-first: cómputo de costo es pure function sobre `ParkingConfig`, exportación es EventKit. Offline informamos al usuario sin bloquearlo, distinto a una app que silenciosamente bloquearía el botón."*

---

### 4.3 PR-B.3 — Demand Insights: last-synced timestamp *(5 pts)*

**Archivos:**
- `Views/Usuario/Dashboard/ParkingDemandInsightsView.swift` (autoría Diego, PR #35) — modificación principal.
- `Views/Usuario/Dashboard/DashboardView.swift` línea ~174 — **1 sola línea** (call site).

**Cambios en `ParkingDemandInsightsView.swift`:**
1. Añadir parámetro al `init`: `lastSyncedAt: Date? = nil` (default `nil` mantiene call sites compatibles).
2. Almacenarlo como `private let lastSyncedAt: Date?`.
3. Añadir `@EnvironmentObject var networkMonitor: NetworkMonitor`.
4. En `sampleSizeCaption` (líneas 139-149), si `!networkMonitor.isConnected` y `lastSyncedAt != nil`, anteponer `"Mostrando datos al \(formatter.string(from: lastSyncedAt!)). Sin conexión.\n"` al captionText existente. Helper `private static let captionFormatter: DateFormatter = { ... shortDateTime ... }()`.

**Cambios en `DashboardView.swift`:**
- En la invocación a `ParkingDemandInsightsView(records:openingHour:closingHour:initialBucket:)` (línea ~174), añadir el argumento `lastSyncedAt: vm.vehicleRecords.first?.timestamp`. NO modificar el resto del archivo.

**Tests:** `ParkingDemandInsightsTests.swift` ya existe. Añadir un caso que verifique el caption cambia cuando se pasa `lastSyncedAt`. Si la vista no es testeable directamente (es View), refactorizar el caption a una static func sobre el modelo y testear esa.

**Defensa oral:** *"La vista deriva 100% de datos cacheados localmente (`vm.vehicleRecords` ya está en memoria). El timestamp del record más reciente es proxy de freshness sin tener que añadir infra de sync nueva — reusamos lo que Mateo ya tiene en `ParkingViewModel`."*

---

### 4.4 PR-B.4 — Login: Microsoft button offline *(5 pts)*

**Archivo:** `Views/Login/LoginView.swift` (autoría compartida — modificar SOLO el bloque del botón Microsoft).

**Cambios:**
1. Añadir `@EnvironmentObject var networkMonitor: NetworkMonitor` después de la línea 12 (`@EnvironmentObject var authVM: AuthViewModel`).
2. Al botón Microsoft (líneas 128-152, autoría Diego PR #22), añadir `.disabled(!networkMonitor.isConnected || authVM.isLoading)`.
3. Justo después del `.padding(.horizontal, 24)` del botón Microsoft (línea 152), insertar:
   ```swift
   if !networkMonitor.isConnected {
       Text("Sin conexión — usa Face ID si tienes sesión guardada")
           .font(.caption)
           .foregroundColor(.secondary)
           .padding(.horizontal, 24)
   }
   ```
4. **NO TOCAR** los botones Email (73-90), Google (101-125), Biometrics (155-175).

**Tests:** verificación manual con simulator offline.

**Defensa oral:** *"Microsoft OAuth requiere internet (provider.credential + Auth.auth().signIn). Lo deshabilitamos visiblemente y dirigimos al usuario al fallback Face ID que ya existe (Juanes). No bloqueamos los demás métodos para no pisar autoría."*

---

## 5. PR-C — NSCache para AI scans (criterio 6, 10 pts)

### 5.1 PR-C.1 — `AIScanCache` singleton

**Archivos nuevos:**
- `Core/AICache/AIScanCache.swift`
- `sd-smart-parkingTests/AIScanCacheTests.swift`

**Diseño:** `final class AIScanCache` envuelve `NSCache<NSString, CachedIdentificationBox>`. Como `VehicleIdentification` es struct, lo boxeamos en un objeto:

```swift
import Foundation
import UIKit
import CryptoKit

final class CachedIdentificationBox: NSObject {
    let value: VehicleIdentification
    let cost: Int
    init(value: VehicleIdentification, cost: Int) {
        self.value = value
        self.cost = cost
    }
}

final class AIScanCache {
    static let shared = AIScanCache()

    /// `countLimit = 30`: ~1 turno de Gerente (8h × 3-4 escaneos/h ≈ 30).
    /// `totalCostLimit = 1 MB`: scans típicos resized a 1280px ≈ 30-50 KB.
    /// 30 entradas × 50 KB ≈ 1.5 MB — el cap de 1 MB fuerza eviction antes.
    private let cache: NSCache<NSString, CachedIdentificationBox> = {
        let c = NSCache<NSString, CachedIdentificationBox>()
        c.countLimit = 30
        c.totalCostLimit = 1 * 1024 * 1024
        return c
    }()

    private init() {}

    // SHA256 hex de la representación JPEG quality 0.7 — estable, colisión-improbable.
    func key(for image: UIImage) -> NSString? {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        let digest = SHA256.hash(data: data)
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return hex as NSString
    }

    func get(_ key: NSString) -> VehicleIdentification? {
        cache.object(forKey: key)?.value
    }

    func put(_ value: VehicleIdentification, for key: NSString, cost: Int) {
        cache.setObject(CachedIdentificationBox(value: value, cost: cost), forKey: key, cost: cost)
    }

    func clear() { cache.removeAllObjects() }
}
```

**Modificación a `ViewModels/VehicleAIScannerViewModel.swift`:**

En `analyze(image:)` (líneas 45-64):
```swift
func analyze(image: UIImage) {
    state = .analyzing
    let prepared = Self.resized(image, maxSide: 1280)

    if let key = AIScanCache.shared.key(for: prepared),
       let cached = AIScanCache.shared.get(key) {
        state = .success(cached)
        return
    }

    Task {
        do {
            let response = try await model.generateContent(prepared, Self.prompt)
            guard let raw = response.text, !raw.isEmpty else {
                self.state = .failure("The AI returned an empty response. Try again.")
                return
            }
            let identification = try Self.decode(raw)
            self.state = .success(identification)

            // Cache write — sólo si la imagen produjo key y el resultado es útil.
            if let key = AIScanCache.shared.key(for: prepared),
               let data = prepared.jpegData(compressionQuality: 0.7) {
                AIScanCache.shared.put(identification, for: key, cost: data.count)
            }
        } catch let decodingError as VehicleAIScannerError {
            self.state = .failure(decodingError.message)
        } catch {
            self.state = .failure("AI error: \(error.localizedDescription)")
        }
    }
}
```

**Tests Swift Testing (`AIScanCacheTests.swift`):**
```swift
@Suite("AIScanCache") struct AIScanCacheTests {
    @Test func storesAndReturns() async throws { ... }
    @Test func differentImagesProduceDifferentKeys() async throws { ... }
    @Test func sameBytesProduceSameKey() async throws { ... }
    @Test func evictsBeyondCountLimit() async throws { ... }
}
```

Helpers de test: crear `UIImage` programáticas con `UIGraphicsImageRenderer` para tener bytes determinísticos.

**Defensa oral:** *"Existe `SpotCacheManager` con NSCache para parking spots (Juanes). Mi `AIScanCache` es un cache distinto: dominio (resultados de Gemini, no spots), llave (SHA256 de imagen, no `floor_X`), valor wrapping (struct boxed en NSObject porque `NSCache` requiere `AnyObject`), `countLimit = 30` y `totalCostLimit = 1 MB` justificados por la jornada típica de un Gerente. Auto-eviction LRU bajo presión de memoria es propiedad gratuita de `NSCache`."*

---

## 6. PR-D — Local Storage low-risk (criterio 4, 15 pts declarables)

### 6.1 PR-D.1 — `@AppStorage` con prefijo `diego.` *(5 pts UserDefaults)*

**Archivos modificados:**

#### `Views/Usuario/Dashboard/TripPlannerSheetView.swift` (autoría Diego)
Añadir antes del `body`:
```swift
@AppStorage("diego.tripPlanner.preferredCurrency") private var preferredCurrency: String = "COP"
```

En la sección "Estimated Cost" (línea 48-66), reemplazar el `HStack` actual por uno que use `preferredCurrency` para mostrar `COP` o `USD` (con conversión hard-coded `let usdRate = 4000.0`). Añadir un `Picker` arriba:
```swift
Picker("Currency", selection: $preferredCurrency) {
    Text("COP").tag("COP")
    Text("USD").tag("USD")
}
.pickerStyle(.segmented)
```

#### `Views/Profile/EditProfileView.swift` (autoría Diego, PR #7)
Añadir:
```swift
@AppStorage("diego.profile.showDemandBadgeOnDashboard") private var showDemandBadge: Bool = true
```
Y un `Toggle("Mostrar badge de demanda en Dashboard", isOn: $showDemandBadge)` en una sección apropiada.

**Tests:** `AppStoragePrefsTests.swift` que escriba/lea de `UserDefaults.standard` con esas llaves y verifique persistencia. Usar `UserDefaults(suiteName:)` para aislar en tests.

**Verificación manual:** abrir TripPlanner → cambiar a USD → cerrar app → reabrir → persiste.

---

### 6.2 PR-D.2 — `ScanHistoryStore` Codable + FileManager *(5 pts archivo local)*

**Archivos nuevos:**
- `Models/ScanHistoryEntry.swift`
- `FileManagers/ScanHistoryStore.swift`
- `Views/Gerente/ScanHistorySheet.swift`
- `sd-smart-parkingTests/ScanHistoryStoreTests.swift`

**`Models/ScanHistoryEntry.swift`:**
```swift
import Foundation

struct ScanHistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let identification: VehicleIdentification
    let scannedAt: Date
    let imageHashHex: String

    init(identification: VehicleIdentification,
         scannedAt: Date = Date(),
         imageHashHex: String) {
        self.id = UUID()
        self.identification = identification
        self.scannedAt = scannedAt
        self.imageHashHex = imageHashHex
    }
}
```

**`FileManagers/ScanHistoryStore.swift`:**
```swift
import Foundation

/// Persistencia local de scans del AI Scanner. Ring-buffer de máx 50 entradas
/// en `Documents/diego.scan_history.json`. Independiente del DiskPersistanceManager
/// (Mateo) — codepath, archivo y estilo separados para autoría limpia.
final class ScanHistoryStore {
    static let shared = ScanHistoryStore()

    private let fileURL: URL
    private let maxEntries: Int
    private let queue = DispatchQueue(label: "com.diego.scanhistory", attributes: .concurrent)

    init(fileURL: URL? = nil, maxEntries: Int = 50) {
        self.fileURL = fileURL ?? Self.defaultURL()
        self.maxEntries = maxEntries
    }

    private static func defaultURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("diego.scan_history.json")
    }

    func loadAll() -> [ScanHistoryEntry] {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL) else { return [] }
            return (try? JSONDecoder().decode([ScanHistoryEntry].self, from: data)) ?? []
        }
    }

    func append(_ entry: ScanHistoryEntry) {
        queue.async(flags: .barrier) {
            var current = (try? Data(contentsOf: self.fileURL))
                .flatMap { try? JSONDecoder().decode([ScanHistoryEntry].self, from: $0) }
                ?? []
            current.insert(entry, at: 0)
            if current.count > self.maxEntries { current = Array(current.prefix(self.maxEntries)) }
            if let data = try? JSONEncoder().encode(current) {
                try? data.write(to: self.fileURL, options: .atomic)
            }
        }
    }

    func clear() {
        queue.async(flags: .barrier) {
            try? FileManager.default.removeItem(at: self.fileURL)
        }
    }
}
```

**Modificaciones:**
- `ViewModels/VehicleAIScannerViewModel.swift`: tras `state = .success(identification)`, calcular `imageHashHex` con `AIScanCache.shared.key(for: prepared)` (ya disponible) y `ScanHistoryStore.shared.append(ScanHistoryEntry(identification:, imageHashHex:))`.
- `Views/Gerente/VehicleAIScannerView.swift`: añadir botón toolbar `History` que abre `ScanHistorySheet`.

**`Views/Gerente/ScanHistorySheet.swift`:** lista simple con `List(ScanHistoryStore.shared.loadAll())`. Cada celda muestra placa, marca, fecha.

**Tests:** round-trip Codable, ring-buffer eviction (51 inserts → primera descartada), corruption recovery (archivo inválido → returns []), inyección de URL temporal con `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)`.

**Defensa oral:** *"Diferente del `DiskPersistanceManager` de Mateo: archivo separado (`diego.scan_history.json`), API ring-buffer específica de scans, dispatch queue propia para concurrencia. No es un Codable manager genérico — es un store especializado."*

---

### 6.3 PR-D.3 — `KeyValueStore<K,V>` hash-based *(5 pts BD k/v propia)*

**Archivos nuevos:**
- `FileManagers/KeyValueStore.swift`
- `Core/ScanStats.swift`
- `sd-smart-parkingTests/KeyValueStoreTests.swift`

**`FileManagers/KeyValueStore.swift`:**
```swift
import Foundation

/// K/V store hash-table-backed con persistencia JSON file por scope.
///
/// Deliberadamente DISTINTO al `ArrayMap` (Mateo): este usa un `Dictionary` interno
/// (O(1) lookup) con scope-namespaced JSON files. ArrayMap usa parallel sorted arrays
/// con binary search (O(log n)). Misma rúbrica (k/v store), implementación distinta.
final class KeyValueStore<Key: Hashable & Codable, Value: Codable> {
    private var storage: [Key: Value] = [:]
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.diego.kvstore", attributes: .concurrent)

    init(scope: String, fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL(scope: scope)
        self.storage = self.load()
    }

    private static func defaultURL(scope: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("diego.kv", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(scope).json")
    }

    private func load() -> [Key: Value] {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let dict = try? JSONDecoder().decode([Key: Value].self, from: data)
            else { return [:] }
            return dict
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(storage) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    subscript(key: Key) -> Value? {
        get { queue.sync { storage[key] } }
        set {
            queue.async(flags: .barrier) {
                if let v = newValue { self.storage[key] = v }
                else { self.storage.removeValue(forKey: key) }
                self.persist()
            }
        }
    }

    func put(_ value: Value, forKey key: Key) { self[key] = value }
    func remove(_ key: Key) { self[key] = nil }
    func snapshot() -> [Key: Value] { queue.sync { storage } }
    var count: Int { queue.sync { storage.count } }
}
```

> **Nota Codable:** `[Key: Value]` se serializa a JSON OK sólo si `Key` es `String` o `Int`. Para llaves complejas envolver en `String(describing: key)` o restringir el genérico. Para nuestro caso de uso `Key = String` (brand) basta.

**`Core/ScanStats.swift`:**
```swift
import Foundation

@MainActor
final class ScanStats: ObservableObject {
    static let shared = ScanStats()
    private let store: KeyValueStore<String, Int>

    init(store: KeyValueStore<String, Int>? = nil) {
        self.store = store ?? KeyValueStore<String, Int>(scope: "scan_brand_count")
    }

    func increment(brand: String) {
        let key = brand.lowercased()
        store[key] = (store[key] ?? 0) + 1
        objectWillChange.send()
    }

    func topBrands(_ n: Int = 3) -> [(brand: String, count: Int)] {
        store.snapshot()
            .sorted { $0.value > $1.value }
            .prefix(n)
            .map { (brand: $0.key, count: $0.value) }
    }
}
```

**Modificaciones:**
- `ViewModels/VehicleAIScannerViewModel.swift`: tras `state = .success(identification)`, llamar `ScanStats.shared.increment(brand: identification.brand)`.
- `Views/Profile/Profile.view.swift`: añadir una sección al final que liste `ScanStats.shared.topBrands(3)`. Esta es la única edición; respetamos el resto del archivo (incluida la convención `Profile.view.swift` per CLAUDE.md "leave the existing anomaly alone").

**Tests:** put/get/remove, persistence reload (instanciar dos veces con misma URL), scope isolation (dos scopes con misma key no se pisan), thread-safety (escrituras concurrentes con `DispatchGroup`).

**Defensa oral:** *"Ya existe `ArrayMap` de Mateo (sorted parallel arrays + binary search, O(log n)). Mi `KeyValueStore` usa `Dictionary` interno (O(1) hash lookup), namespace de archivos separado (`diego.kv/<scope>.json`), API genérica scope-based. Misma fila del rúbric, implementación distinta y código fuente de Diego."*

---

## 7. PR-E — Keychain (criterio 4, +5 pts redundancia)

### 7.1 PR-E.1 — `KeychainHelper` + Microsoft user identifier

**Archivos nuevos:**
- `Core/KeychainHelper.swift`
- `sd-smart-parkingTests/KeychainHelperTests.swift`

**`Core/KeychainHelper.swift`:**
```swift
import Foundation
import Security

/// Wrapper minimal sobre Security framework. Sin packages externos.
/// Usa kSecClassGenericPassword + kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
/// para que las credenciales sobrevivan reboots pero NO se backupeen a iCloud.
enum KeychainHelper {

    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }

    static func set(_ data: Data, account: String, service: String) throws {
        // Borrar si ya existe — kSecValueData en Add no actualiza.
        delete(account: account, service: service)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    static func get(account: String, service: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    static func delete(account: String, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
```

**Modificación a `ViewModels/AuthViewModel.swift` (sólo bloque `signInWithMicrosoft`, líneas 197-211):**

Tras éxito del login, persistir `Auth.auth().currentUser?.uid` y `currentUser?.email` en Keychain con `service = "com.sdparking.microsoft"`. Ejemplo:
```swift
// Tras la línea try await Auth.auth().signIn(with: credential)
if let user = Auth.auth().currentUser, let email = user.email,
   let uidData = user.uid.data(using: .utf8),
   let emailData = email.data(using: .utf8) {
    try? KeychainHelper.set(uidData, account: "uid", service: "com.sdparking.microsoft")
    try? KeychainHelper.set(emailData, account: "email", service: "com.sdparking.microsoft")
}
```

**Modificación a `Views/Login/LoginView.swift`:** justo antes del botón Microsoft (línea 128), añadir un botón secundario **sólo si Keychain devuelve datos**:
```swift
if let emailData = KeychainHelper.get(account: "email", service: "com.sdparking.microsoft"),
   let lastEmail = String(data: emailData, encoding: .utf8) {
    Text("Last Microsoft user: \(lastEmail)")
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 24)
}
```

**Tests:** unit con `protocol KeychainStoring` extraído + `InMemoryKeychain` mock (justified protocol extraction per CLAUDE.md). Round-trip set/get/delete, key isolation entre services.

**Verificación manual:** `simctl shutdown booted; xcrun simctl boot ...` → user identifier persiste en login screen.

**Defensa oral:** *"Ningún teammate ha tocado Keychain. `SecItemAdd/Copy/Delete` directos, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` para no leakear a iCloud backup. Service namespace `com.sdparking.microsoft` para no chocar si después agregamos otros providers."*

---

## 8. PR-F — LRU manual para Trip Planner (criterio 6, +10 pts)

### 8.1 PR-F.1 — `LRUCache<Key, Value>` doubly-linked list + dictionary

**Archivos nuevos:**
- `Core/LRUCache.swift`
- `Models/TripCacheKey.swift`
- `sd-smart-parkingTests/LRUCacheTests.swift`

**`Core/LRUCache.swift`:**
```swift
import Foundation

/// LRU cache implementado con doubly-linked list + dictionary, O(1) get/put.
///
/// Estructura DISTINTA a las que ya existen en el proyecto:
/// - SpotCacheManager (Juanes) usa NSCache con eviction implícito por presión de memoria.
/// - ArrayMap (Mateo) usa parallel sorted arrays con binary search.
/// - Esta clase usa nodos enlazados + map: capacity fija, eviction determinista LRU.
///
/// Demuestra la implementación canónica del cache LRU que se enseña en cursos
/// de estructuras de datos.
final class LRUCache<Key: Hashable, Value> {

    private final class Node {
        var key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }

    private let capacity: Int
    private var nodes: [Key: Node] = [:]
    private var head: Node?  // MRU
    private var tail: Node?  // LRU

    init(capacity: Int) {
        precondition(capacity > 0, "LRUCache capacity must be > 0")
        self.capacity = capacity
    }

    var count: Int { nodes.count }

    func get(_ key: Key) -> Value? {
        guard let node = nodes[key] else { return nil }
        moveToFront(node)
        return node.value
    }

    func put(_ value: Value, for key: Key) {
        if let existing = nodes[key] {
            existing.value = value
            moveToFront(existing)
            return
        }
        let node = Node(key: key, value: value)
        nodes[key] = node
        addToFront(node)
        if nodes.count > capacity, let lru = tail {
            removeNode(lru)
            nodes.removeValue(forKey: lru.key)
        }
    }

    func clear() {
        nodes.removeAll()
        head = nil
        tail = nil
    }

    // MARK: - List ops

    private func addToFront(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil { tail = node }
    }

    private func removeNode(_ node: Node) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
        if node === head { head = node.next }
        if node === tail { tail = node.prev }
        node.prev = nil
        node.next = nil
    }

    private func moveToFront(_ node: Node) {
        guard node !== head else { return }
        removeNode(node)
        addToFront(node)
    }
}
```

**`Models/TripCacheKey.swift`:**
```swift
import Foundation

/// Llave compuesta para cachear costos de viajes calculados.
/// Buckets de 5 minutos en arrival y 5 minutos en duration permiten que ajustes
/// pequeños del slider hagan cache HIT (vs key exacta del Date que nunca pegaría
/// salvo en clicks idénticos).
struct TripCacheKey: Hashable {
    let arrivalBucket: Int     // arrivalDate.timeIntervalSince1970 / 300
    let durationBucket: Int    // durationHours * 12 (5-min buckets)

    init(arrivalDate: Date, durationHours: Double) {
        self.arrivalBucket = Int(arrivalDate.timeIntervalSince1970 / 300.0)
        self.durationBucket = Int(durationHours * 12.0)
    }
}
```

**Modificación a `ViewModels/TripPlannerViewModel.swift` (sólo Diego):**
```swift
private let costCache = LRUCache<TripCacheKey, Double>(capacity: 5)

func estimatedCost() -> Double {
    let key = TripCacheKey(arrivalDate: arrivalDate, durationHours: durationHours)
    if let cached = costCache.get(key) { return cached }
    let cost = ParkingConfig.calculateFee(hours: durationHours, currentDayTotal: 0)
    costCache.put(cost, for: key)
    return cost
}
```

**Tests Swift Testing (`LRUCacheTests.swift`):**
```swift
@Suite("LRUCache") struct LRUCacheTests {
    @Test func capacityOverflowEvictsLRU() async throws {
        let c = LRUCache<String, Int>(capacity: 2)
        c.put(1, for: "a"); c.put(2, for: "b"); c.put(3, for: "c")
        #expect(c.get("a") == nil)
        #expect(c.get("b") == 2)
        #expect(c.get("c") == 3)
    }

    @Test func getPromotesToMRU() async throws {
        let c = LRUCache<String, Int>(capacity: 2)
        c.put(1, for: "a"); c.put(2, for: "b")
        _ = c.get("a")              // a → MRU, b → LRU
        c.put(3, for: "c")          // evict b
        #expect(c.get("b") == nil)
        #expect(c.get("a") == 1)
    }

    @Test func putUpdatesExistingValue() async throws {
        let c = LRUCache<String, Int>(capacity: 2)
        c.put(1, for: "a"); c.put(99, for: "a")
        #expect(c.get("a") == 99)
        #expect(c.count == 1)
    }

    @Test func emptyCacheReturnsNil() async throws {
        let c = LRUCache<String, Int>(capacity: 5)
        #expect(c.get("anything") == nil)
    }
}
```

**Defensa oral:** *"Implementé LRU manual porque el rúbric pide explicar parámetros y decisiones. Capacity 5 porque el usuario típico explora 2-3 alternativas de horario antes de decidir; doubly-linked list + dictionary es el patrón canónico O(1) que se enseña en cursos. Buckets de 5-min en la key permiten reuso real entre ajustes pequeños del slider, no key exacta del Date."*

---

## 9. PR-G — SwiftData (criterio 4, +10 pts BD relacional)

### 9.1 PR-G.1 — `SavedTripPlan` @Model + `.modelContainer`

**Archivos nuevos:**
- `Models/SavedTripPlan.swift`
- `Models/TripExportSnapshot.swift`
- `Views/Usuario/Dashboard/TripHistoryView.swift`
- `sd-smart-parkingTests/SavedTripPlanTests.swift`

**`Models/SavedTripPlan.swift`:**
```swift
import Foundation
import SwiftData

@Model
final class SavedTripPlan {
    @Attribute(.unique) var id: UUID
    var arrivalDate: Date
    var leaveDate: Date
    var parkingName: String
    var estimatedCostCOP: Double
    var createdAt: Date
    var wasExportedToCalendar: Bool

    init(id: UUID = UUID(),
         arrivalDate: Date,
         leaveDate: Date,
         parkingName: String,
         estimatedCostCOP: Double,
         createdAt: Date = Date(),
         wasExportedToCalendar: Bool = false) {
        self.id = id
        self.arrivalDate = arrivalDate
        self.leaveDate = leaveDate
        self.parkingName = parkingName
        self.estimatedCostCOP = estimatedCostCOP
        self.createdAt = createdAt
        self.wasExportedToCalendar = wasExportedToCalendar
    }
}
```

**`Models/TripExportSnapshot.swift`** (DTO desde el VM no-MainActor):
```swift
import Foundation

struct TripExportSnapshot {
    let arrivalDate: Date
    let leaveDate: Date
    let parkingName: String
    let estimatedCostCOP: Double
    let wasExportedToCalendar: Bool
}
```

**Modificación a `sd_smart_parkingApp.swift` (1 línea — minimizar conflicto de merge):**
```swift
import SwiftUI
import SwiftData                       // ← nuevo
import FirebaseCore

// ...

WindowGroup {
    ContentView()
        .environmentObject(navigationManager)
        .environmentObject(networkMonitor)
        .preferredColorScheme(.light)
        .modelContainer(for: SavedTripPlan.self)   // ← nuevo (1 línea)
}
```

**Modificación a `ViewModels/TripPlannerViewModel.swift`:** añadir factory pura (no toca `@Model`, sólo struct):
```swift
func makeExportSnapshot(parkingName: String) -> TripExportSnapshot {
    TripExportSnapshot(
        arrivalDate: arrivalDate,
        leaveDate: leaveDate,
        parkingName: parkingName,
        estimatedCostCOP: estimatedCost(),
        wasExportedToCalendar: didExport
    )
}
```

**Modificación a `Views/Usuario/Dashboard/TripPlannerSheetView.swift`:** acceder al model context y persistir tras export exitoso.
```swift
@Environment(\.modelContext) private var modelContext
// ...
.onChange(of: tripVM.didExport) { _, didExport in
    guard didExport else { return }
    let snap = tripVM.makeExportSnapshot(parkingName: config.parkingName)
    let saved = SavedTripPlan(
        arrivalDate: snap.arrivalDate,
        leaveDate: snap.leaveDate,
        parkingName: snap.parkingName,
        estimatedCostCOP: snap.estimatedCostCOP,
        wasExportedToCalendar: true
    )
    modelContext.insert(saved)
    try? modelContext.save()
}
```

**`Views/Usuario/Dashboard/TripHistoryView.swift`:**
```swift
import SwiftUI
import SwiftData

struct TripHistoryView: View {
    @Query(sort: \SavedTripPlan.createdAt, order: .reverse) private var trips: [SavedTripPlan]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(trips) { trip in
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.parkingName).font(.headline)
                    Text("Llegada: \(trip.arrivalDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                    Text("COP \(Int(trip.estimatedCostCOP))")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                }
            }
            .navigationTitle("Historial de viajes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
```

Acceso desde `TripPlannerSheetView` toolbar o desde el Dashboard como navegación nueva.

**Tests Swift Testing:**
```swift
@Suite("SavedTripPlan") struct SavedTripPlanTests {
    @Test @MainActor func insertAndQuery() async throws {
        let schema = Schema([SavedTripPlan.self])
        let config = ModelConfiguration("test", schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let trip = SavedTripPlan(
            arrivalDate: Date(),
            leaveDate: Date().addingTimeInterval(3600),
            parkingName: "SD",
            estimatedCostCOP: 5000
        )
        context.insert(trip)
        try context.save()

        let descriptor = FetchDescriptor<SavedTripPlan>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.parkingName == "SD")
    }
}
```

**Riesgos & mitigación (R10):** SwiftData `@Model` instances son MainActor por defecto en Swift 5.9+. Insertamos SÓLO desde la vista (`TripPlannerSheetView`, MainActor implícito). El VM expone un struct DTO `TripExportSnapshot` (no `@Model`); la vista construye `SavedTripPlan(...)` y llama `modelContext.insert(...)`.

**Defensa oral:** *"Elegí SwiftData sobre CoreData para evitar boilerplate y porque su default `MainActor` coincide con el setting global del proyecto (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). El `@Model` se instancia y se inserta SÓLO desde la vista (que ya es MainActor); el VM expone un DTO struct para evitar atravesar boundaries de actor con el `@Model` directamente."*

---

## 10. Riesgos y mitigaciones

| # | Riesgo | Mitigación |
|---|---|---|
| R1 | SwiftData `@Model` choca con MainActor global o con Firestore listeners en `ParkingViewModel` | `SavedTripPlan` aislado; insertar SOLO desde la vista (no desde la VM); test in-memory `ModelContainer` |
| R2 | Conflicto de merge en `sd_smart_parkingApp.swift` | PR-G modifica 1 sola línea; coordinar timing con teammates |
| R3 | `NSCache<NSString, NSData>` falla porque Diego intenta wrap struct directamente | Box class `CachedIdentificationBox: NSObject` (decisión ya documentada en plan) |
| R4 | Una feature de Diego rompe build de teammates al introducir `import SwiftData` global | `import SwiftData` queda en archivos nuevos de Diego; `.modelContainer` sólo en `WindowGroup` |
| R5 | Test target XCTest vs Swift Testing — ambigüedad | Verificar framework existente leyendo un test. Asumimos Swift Testing (CLAUDE.md modern default); si es XCTest, se adapta |
| R6 | Evaluador rechaza redundancia ("ya existe ArrayMap, no cuenta tu KeyValueStore") | Docstring contrasta hash table vs sorted parallel arrays explícitamente; namespace de archivos distinto |
| R7 | Firma de `init` de `ParkingDemandInsightsView` rompe call site en `DashboardView` | Default `lastSyncedAt: Date? = nil` mantiene call sites compatibles |
| R8 | NSCache requiere `AnyObject` → struct directo no compila | `CachedIdentificationBox` (R3 mismo) |
| R9 | `NetworkMonitor` no se puede mockear para unit tests | `protocol NetworkConditionsProviding` (PR-A); mocks usan `MockNetworkConditions` |
| R10 | SwiftData `@Model` instanciado fuera de MainActor | VM expone DTO struct `TripExportSnapshot`; SOLO la vista construye e inserta |
| R11 | Llaves de UserDefaults colisionan con las del compañero | Prefix `diego.*` en TODAS las llaves nuevas |

---

## 11. Verificación end-to-end (cierre por feature)

Tras implementar las 11 features, verificar:

1. **Build:** `XcodeBuildMCP build_sim` con scheme `sd-smart-parking` + iPhone 17 (iOS 26.4) → 0 errores, 0 warnings nuevos.
2. **Tests:** `XcodeBuildMCP test_sim` → todas las pruebas existentes verdes + las nuevas (1 `@Suite` por feature mínimo, excepto B.1-B.4 que son UI).
3. **Manual UI:**
   - VehicleAI Scanner offline → `OfflineNoticeBadge` + cae a `PlateOCRSheet`. Online segundo scan misma foto → instantáneo (cache hit).
   - TripPlanner → toggle COP↔USD persiste tras matar app. Add to Calendar → aparece en `TripHistoryView` (SwiftData). Offline → badge visible, botón sigue habilitado.
   - LoginView offline → botón Microsoft gris + caption Face ID. Login MS exitoso → reboot sim → "Last Microsoft user" aparece.
   - Demand Insights offline → caption con timestamp + "Sin conexión".
   - Gerente Profile → "Top 3 brands" sección visible tras hacer 5+ scans.
4. **Autoría:** `git log --author=az4diegoz --oneline | head -20` muestra los 7 PRs de sprint 3; `git blame` en cada archivo nuevo confirma `Diego Benavides`.
5. **Defensa oral:** secciones 4-9 + § 12 a continuación están listas como crib durante el viva voce.

---

## 12. Defensa oral — Criterio 3 (Multithreading) ya cubierto

Diego YA tiene 20/20 en criterio 3 vía PRs #20/#21/#22/#37. Crib oral con citas exactas:

| Estrategia | Cita más fuerte | PR |
|---|---|---|
| Corrutina con dispatcher | `ViewModels/CalendarExportViewModel.swift:44` (`async` + `await MainActor.run` líneas 91, 98, 106) | #21 |
| Anidadas I/O | `ViewModels/CalendarExportViewModel.swift:50-52` (3 niveles: requestWriteOnlyAccess → saveEvent → showAlert) | #21 |
| I/O + Main | `Views/Gerente/PlateOCRScannerView.swift:79-89` (`DispatchQueue.global(.userInitiated).async` + `DispatchQueue.main.async`) | #20 |
| Task results | `ViewModels/VehicleAIScannerViewModel.swift:49-63` (`Task { ... self.state = .success(identification) }`) | #37 |

**Pregunta-respuesta tipo:**

> *"¿Por qué usaste `await MainActor.run { ... }` explícito en lugar de marcar la VM como `@MainActor`?"*

**Respuesta:** *"Las VMs de Diego (`CalendarExportViewModel`, `TripPlannerViewModel`, `AuthViewModel`) son `class : ObservableObject` no-MainActor por consistencia con las VMs preexistentes del proyecto (CLAUDE.md operating principle: match existing patterns). Los métodos `async` corren fuera de Main por defecto, así que muto `@Published` con `await MainActor.run`. Es exactamente la 'corrutina con dispatcher' del rúbric. Sólo `VehicleAIScannerViewModel` (PR #37) es `@MainActor` a nivel de clase porque era código nuevo sin precedente."*

**Comandos para reproducir autoría en oral:**
```bash
git blame sd-smart-parking/Views/Gerente/PlateOCRScannerView.swift -L 79,90
git blame sd-smart-parking/ViewModels/CalendarExportViewModel.swift -L 44,113
git blame sd-smart-parking/ViewModels/VehicleAIScannerViewModel.swift -L 45,64
```

---

## 13. Estado y próximos pasos

| PR | Estado | Notas |
|---|---|---|
| A | 🟨 in-progress | Este doc + `NetworkConditionsProviding.swift` + `OfflineNoticeBadge.swift` |
| B.1 | 🟥 todo | VehicleAI Scanner offline fallback |
| B.2 | 🟥 todo | TripPlanner offline badge |
| B.3 | 🟥 todo | DemandInsights last-synced |
| B.4 | 🟥 todo | LoginView Microsoft button offline |
| C.1 | 🟥 todo | NSCache AIScanCache |
| D.1 | 🟥 todo | @AppStorage prefijo `diego.*` |
| D.2 | 🟥 todo | ScanHistoryStore Codable |
| D.3 | 🟥 todo | KeyValueStore + ScanStats |
| E.1 | 🟥 todo | KeychainHelper + MS user id |
| F.1 | 🟥 todo | LRUCache + TripPlanner |
| G.1 | 🟥 todo | SwiftData SavedTripPlan |

**Orden recomendado:** A (este PR) → B → C → D → F → G. PR-E (Keychain) queda como buffer si alcanza el tiempo (el cap de criterio 4 ya se garantiza con D + G).
