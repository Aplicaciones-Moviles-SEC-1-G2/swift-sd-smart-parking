# Sprint 4 Wiki — Juan Esteban Jiménez (Juanes)
> ISIS-3510 · Construcción de Aplicaciones Móviles · SD Smart Parking · Group 2
> Deadline: May 23, 2026 — 5:00 AM

---

## Author

**Juan Esteban Jiménez Bedoya** — known as "Juanes" in the team.  
All sections in this document describe work done exclusively by Juanes unless otherwise noted.

---

## A. All Features by Sprint

This section lists every feature delivered across all three sprints, with design details for each.

---

### SPRINT 2 Features

---

#### S2-F1 — Face ID / Biometric Authentication

**Files:** `Views/Login/BiometricLockView.swift`, `ViewModels/AuthViewModel.swift`  
**Where in app:** App launch → shown automatically before login screen if enabled

**Design details:**
- Uses `LocalAuthentication` framework (`LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`)
- On successful Face ID evaluation the app transitions directly to the main tab view, bypassing the email/password form
- Falls back gracefully to the standard login form if biometrics are unavailable or the user cancels
- Evaluated on app foreground via `scenePhase` observation so a backgrounded session is re-locked

**Why it matters:** One-tap access removes the login barrier for daily commuters who use the app multiple times per day.

---

#### S2-F2 — QR Code Entry / Exit Scanner

**Files:** `Views/Parking/QRScannerView.swift`, `ViewModels/ParkingViewModel.swift`  
**Where in app:** Manager view → scan button; or entry/exit kiosk flow

**Design details:**
- Uses `AVFoundation` `AVCaptureSession` with a `AVMetadataObjectTypeQRCode` filter
- Decoded QR payload contains the spot identifier; `ParkingViewModel` matches it against the live `spots` collection
- On a valid QR scan a `vehicleRecord` document is written to Firestore with `type = "entry"` or `"exit"`, `timestamp`, `floor`, and `plate`
- Invalid / duplicate scans show an inline error with haptic feedback
- Works offline: if `NetworkMonitor.isConnected == false`, the scan action is queued in `PendingActionsQueue` and replayed on reconnect

**Why it matters:** Eliminates paper tickets and manual log entry, reducing per-car processing time.

---

#### S2-F3 — Real-time Spot Availability (Live Firestore Listener)

**Files:** `ViewModels/ParkingViewModel.swift`, `Views/Parking/SpotsView.swift`  
**Where in app:** "Spots" tab — grid of coloured spot cards per floor

**Design details:**
- `ParkingViewModel` attaches a `Firestore.collection("parkingSpots").addSnapshotListener` on app launch
- Each document change triggers `objectWillChange` on the `@MainActor`-bound ViewModel
- `@Published var spots: [ParkingSpot]` is the source of truth for all views
- `floorAvailability` derived property (micro-optimised in S4 — see Section B) aggregates availability per floor
- `SpotsView` renders a `LazyVGrid` of `SpotCard` components, colour-coded green (available) / red (occupied)
- `BQ-3` (busiest floor) and `BQ-4` (peak hours) are derived from this same data stream

**Why it matters:** Drivers see real occupancy before leaving their office, avoiding wasted trips to full floors.

---

#### S2-F4 — Basic Analytics Dashboard

**Files:** `analytics-dashboard-UN.html`  
**Where in app:** Web dashboard (opened by manager in browser), accessible from the team's shared URL

**Design details:**
- Chart.js bar/doughnut charts fetching directly from Firestore REST API
- S2 sections: BQ-3 (live floor occupancy) and BQ-4 (peak hours heatmap 7–11 AM)
- Collapsible `<details>` sections per BQ, each with author badge and data source description
- Auto-refreshes by calling `load()` which replays all Firestore queries

---

### SPRINT 3 Features

---

#### S3-F1 — AI Vehicle Scanner (Gemini 2.5-flash-lite)

**Files:** `Views/Gerente/VehicleAIScannerView.swift`, `ViewModels/VehicleAIScannerViewModel.swift`  
**Where in app:** Manager tab → camera icon → AI scan sheet

**Design details:**
- Captures JPEG from `AVCaptureSession` or photo library
- Image is SHA-256 hashed; if the hash key is in `AIScanCache` (NSCache, 30 entries / 1 MB) the cached result is returned in < 5 ms — no network call
- On cache miss the JPEG bytes are sent to `GenerativeModel("gemini-2.5-flash-lite")` with a structured prompt requesting plate, brand, color, and `ocrConfidence` (0–1)
- Response is parsed into a `VehicleScanResult` struct and written to Firestore as a `vehicleRecord`
- `ocrConfidence < 0.75` sets `needsReview = true` on the record — surfaced in BQ-RELIABILITY
- `ScanHistoryStore` (JSON ring-buffer, 50 entries) persists the last 50 results to disk for offline review

**Multi-threading:** Gemini network call runs via `async/await`; the `@MainActor`-bound ViewModel updates the UI on the main thread after the call resolves.

**Caching:** `AIScanCache` (NSCache + SHA-256 key) prevents duplicate API calls for the same vehicle image.

---

#### S3-F2 — Trip Planner with Cost Estimation

**Files:** `Views/Usuario/Dashboard/TripPlannerSheetView.swift`, `ViewModels/TripPlannerViewModel.swift`  
**Where in app:** Dashboard tab → "Plan Trip" card → sheet

**Design details:**
- User inputs planned arrival time and expected duration
- `TripPlannerViewModel` calls `ParkingConfig.calculateFee(hours:currentDayTotal:)` which enforces the COP $16,000 daily cap
- Results are cached in `LRUCache<TripCacheKey, Double>` (capacity: 5 entries, O(1) get/put via doubly-linked list + dictionary) — identical (arrival, duration) pairs are resolved without recalculation
- Completed plans are persisted to SwiftData (`@Model SavedTripPlan`) for history
- Offline: calculates locally using the cached rate — no network dependency

**Caching:** Hand-rolled `LRUCache` with O(1) eviction — the first purpose-built cache introduced in S3.

---

#### S3-F3 — Demand Insights View

**Files:** `Views/Usuario/Dashboard/ParkingDemandInsightsView.swift`, `Models/ParkingDemandInsights.swift`  
**Where in app:** Dashboard tab → "Demand Insights" card → sheet

**Design details:**
- Reads `vehicleRecords` from Firestore and computes peak/valley hour buckets
- `ParkingDemandInsights` model classifies each hour as `peak` (7–11 AM), `valley`, or `normal` based on entry count percentile
- Shows best entry and exit windows as plain-language recommendations ("Enter before 7 AM to avoid peak pricing")
- Uses `Charts` framework for the hourly bar chart

---

#### S3-F4 — Personalized Floor Recommendation

**Files:** `Views/Usuario/Navigation/AIRecomendationCard.swift`, `ViewModels/ParkingViewModel.swift`  
**Where in app:** Dashboard tab → recommendation card below the main header

**Design details:**
- Reads `mobilityPreferences` from user profile (elevator required, distance sensitivity)
- `lowestFloorWithAvailability` computed property on `ParkingViewModel` filters `floorAvailability` by user constraints
- Surfaces the recommended floor as a prominent card with a "Navigate" CTA that deep-links to Apple Maps / Google Maps

---

#### S3-F5 — NetworkMonitor + Offline Mode + PendingActionsQueue

**Files:** `Core/NetworkMonitor.swift`, `FileManagers/PendingActionsQueue.swift`  
**Where in app:** Visible as orange banner in any view when device is offline

**Design details:**
- `NetworkMonitor` wraps `NWPathMonitor` on a dedicated background `DispatchQueue`; path updates are relayed to `@MainActor` via `DispatchQueue.main.async`
- `@Published var isConnected: Bool` drives offline banners in all feature views
- `PendingActionsQueue` serialises `.entry`, `.exit`, and `.spotUpdate` actions to `Documents/pending_actions.json` using atomic writes (`Data.write(to:options:.atomic)`) — no partial-write corruption
- On reconnect `syncPendingActions()` is called, draining the queue in FIFO order and writing each action to Firestore

**Multi-threading:** NWPathMonitor runs on a background queue; UI state updates hop to MainActor via `DispatchQueue.main.async`.

**Local storage:** `pending_actions.json` with atomic writes guarantees durability across crashes.

---

#### S3-F6 — Caching Infrastructure (LRUCache, SpotCacheManager, AIScanCache)

**Files:** `Core/LRUCache.swift`, `Core/SpotCacheManager.swift`, `ViewModels/VehicleAIScannerViewModel.swift`

**Design details:**
- `LRUCache<K,V>`: hand-rolled doubly-linked list + Swift Dictionary; `get` and `put` both O(1). Used for trip-cost memoisation with capacity 5.
- `SpotCacheManager`: NSCache wrapping `[ParkingSpot]` arrays keyed by `"floor_N"`; configured with `countLimit = 500` and `totalCostLimit = 2_000_000` (2 MB). Pre-warms floor data after the initial Firestore load.
- `AIScanCache`: NSCache keyed by SHA-256 hex digest of the JPEG payload; 30 entries / 1 MB. Prevents duplicate Gemini calls.

---

#### S3-F7 — Dashboard S3 BQs (5 new BQs added to analytics-dashboard-UN.html)

**BQs added:** BQ-ORG, BQ-HOUR, BQ-FLOOR, BQ-RELIABILITY, BQ-13  
See Section B for full descriptions.

---

### SPRINT 4 Features

---

#### S4-F1 — Personal Parking Analytics

**Files:**
- `ViewModels/PersonalStatsViewModel.swift`
- `Views/Usuario/ActiveInfo/PersonalStatsView.swift`

**Where in app:** Profile tab → Analytics section → tap "My Parking Stats"

**Design details:**
- Dedicated analytics screen for the logged-in driver (hidden from manager accounts via `!authVM.isGerente`)
- **UI layout:** Three stat cards row (sessions / total time / total paid) → avg session gauge card → insight row (busiest weekday + favourite floor) → horizontal bar chart of avg duration per weekday (Mon–Sun)
- **Data source:** `vm.vehicleRecords` filtered by the user's registered plate numbers (`authVM.currentUser?.cars.allValues()`)
- **Loading state:** `ProgressView` spinner with "Computing your stats…" caption while async tasks run
- **Empty state:** Full-width card with car icon and explanatory text if no exit records exist
- **Offline state:** Orange banner + "Cached \(savedAt, style: .date)" footer when serving disk data

**Multi-threading strategy (`async let` — 5 parallel tasks):**  
Sendable-safe primitive arrays are extracted from `vehicleRecords` on the MainActor, then five `nonisolated static async` helpers fire concurrently as child tasks of the calling task. Swift's cooperative thread pool distributes them across available CPU cores:
```swift
async let sessionsTask   = Self.countItems(timestamps.count)
async let hoursTask      = Self.sumDoubles(durations)
async let busiestDayTask = Self.findBusiestWeekday(timestamps)
async let floorTask      = Self.findMostFrequentFloor(floors)
async let weekdaysTask   = Self.avgDurationsByWeekday(tsAndDur)
let (sessions, hours, busDay, topFloor, weekdays) = await (
    sessionsTask, hoursTask, busiestDayTask, floorTask, weekdaysTask)
```

**Caching strategy (two-layer):**
- Layer 1 — `NSCache<NSString, PersonalStatsBox>` (countLimit=3): in-process, evicted by OS under memory pressure; re-renders within the same session cost 0 ms
- Layer 2 — `KeyValueStore<String, PersonalStatsSnapshot>(scope: "juanes.personal_stats")`: JSON on disk at `Documents/diego.kv/juanes.personal_stats.json`; survives app restarts and terminations

**Local storage strategy:**  
`KeyValueStore` uses a `DispatchQueue(attributes: .concurrent)` with `.barrier` writes for thread-safe file access. `JSONEncoder` serialises the Codable `PersonalStatsSnapshot` atomically.

**Eventual connectivity strategy:**
```swift
.task {
    if !networkMonitor.isConnected {
        statsVM.loadCachedIfOffline(userPlates: userPlates)
    } else {
        await statsVM.load(records: vm.vehicleRecords, userPlates: userPlates)
    }
}
```
`loadCachedIfOffline` checks the NSCache first, then falls back to the disk store. The `isOfflineCopy` flag drives the "Cached …" footer.

---

#### S4-F2 — Floor Monitor

**Files:**
- `ViewModels/FloorMonitorViewModel.swift`
- `Views/Parking/FloorMonitorView.swift`

**Where in app:** Spots tab → tap 📡 antenna icon in the navigation bar (top-left)

**Design details:**
- Presents as a modal sheet (`NavigationStack` inside `.sheet`)
- **UI layout:** Refresh header (last-updated timestamp / spinner) → "Watched Floors" section (orange star.fill icon, only if ≥1 floor starred) → "All Floors" / "Other Floors" section
- **Floor card:** coloured floor-number badge (green >50% free, orange >20%, red otherwise) → "X / Y free" + trend arrow (↑↓—) → occupancy bar (GeometryReader proportional fill) → avg stay text → ⭐ star toggle button
- **Trend arrows:** compared against the previous snapshot's `available` count — `up` if more spots free, `down` if fewer, `same` if equal
- **Auto-refresh:** background `.task {}` loop refreshes every 30 seconds for the entire sheet lifetime; also triggers on `vm.spots.count` change via `.onChange`
- **Toolbar:** Done (cancellationAction) + manual refresh button (disabled while `isRefreshing`)

**Multi-threading strategy (`withTaskGroup` — 1 child task per floor):**  
Each floor's slice of `spots` and `vehicleRecords` is processed by a separate child task in a `withTaskGroup`. Tasks run concurrently on the cooperative thread pool; results are collected via `for await snap in group`:
```swift
await withTaskGroup(of: FloorSnapshot.self) { group in
    for floor in floors {
        let floorSpots   = spots.filter   { $0.floor == floor }
        let floorRecords = records.filter { $0.floor == floor }
        group.addTask {
            let available = floorSpots.filter { $0.isAvailable }.count
            let exits     = floorRecords.filter { $0.type == .exit }
            let avgStay   = exits.isEmpty ? 0.0
                          : exits.compactMap { $0.durationHours }.reduce(0,+) / Double(exits.count)
            return FloorSnapshot(floor: floor, available: available,
                                 total: floorSpots.count, avgStayHours: avgStay, ...)
        }
    }
    for await snap in group { newSnapshots[snap.floor] = snap }
}
```

**Local storage strategy:**  
`watchedFloors: Set<Int>` (starred floors) is persisted as a sorted `[Int]` array in `KeyValueStore<String, [Int]>(scope: "juanes.floor_watch")` at `Documents/diego.kv/juanes.floor_watch.json`. Loaded on `init()` so starred floors survive app restarts.

**Eventual connectivity strategy:**  
Orange "Offline — showing last snapshot" banner when `!networkMonitor.isConnected`. The last-computed `floorSnapshots` dictionary remains in memory and is still displayed. The `lastRefreshed` date is shown as a relative timestamp so the user knows how stale the data is.

---

#### S4-F3 — My History (Upgraded — Actor-backed Session Log)

**Files:**
- `ViewModels/ParkingHistoryViewModel.swift`
- `Views/Usuario/ActiveInfo/MyHistoryView.swift`

**Where in app:** Dashboard tab → "My History" card (clock icon)

**Design details:**
- Replaced the previous plain computed-property list with a fully cached, concurrency-backed session view
- **UI layout:** Offline banner (if needed) → summary card (sessions / total time / total paid for current filter) → segmented filter picker (All / Week / Month / Year) → sessions grouped by calendar month (section headers) → per-session rows
- **Session row:** floor badge (floor number + "F") → plate monospaced + optional "CAP" chip (orange, shown if `hitDailyCap`) → date + time → duration + cost (right-aligned)
- **Filters:** `HistoryFilter` enum cases map to `Calendar.isDate(_:equalTo:toGranularity:)` — e.g. `.month` keeps only sessions in the current calendar month
- **Grouping:** `sessionsByMonth` sorts groups so the most recent month appears first; within a group sessions are sorted newest-first
- **Loading state:** ProgressView spinner card
- **Empty state:** car.fill system image with explanatory text

**Multi-threading strategy (Swift `actor` — HistoryProcessor):**  
A `private actor HistoryProcessor` owns the filtering and mapping logic. Actors run on their own executor — calling `await processor.buildSessions(...)` from the `@MainActor`-bound ViewModel automatically moves work off the main thread without any explicit `DispatchQueue` management:
```swift
private actor HistoryProcessor {
    func buildSessions(from records: [VehicleRecord],
                       userPlates: Set<String>) -> [ParkingSession] {
        records
            .filter { $0.type == .exit && userPlates.contains($0.plate.uppercased()) }
            .compactMap { r -> ParkingSession? in
                guard let dur = r.durationHours, dur > 0 else { return nil }
                let cost = ParkingConfig.calculateFee(hours: dur, currentDayTotal: 0)
                return ParkingSession(id: "\(r.plate)-\(r.timestamp.timeIntervalSince1970)",
                                      plate: r.plate, floor: r.floor ?? 0,
                                      date: r.timestamp, durationHours: dur,
                                      costCOP: cost, hitCap: r.hitDailyCap)
            }
            .sorted { $0.date > $1.date }
    }
}
// ViewModel calls it — work automatically leaves MainActor
let built = await processor.buildSessions(from: records, userPlates: userPlates)
```

**Caching strategy (two-layer):**
- Layer 1 — `NSCache<NSString, HistoryBox>` (countLimit=3): in-process, zero-cost re-renders within the session
- Layer 2 — `KeyValueStore<String, ParkingHistoryCache>(scope: "juanes.parking_history")`: JSON on disk at `Documents/diego.kv/juanes.parking_history.json`

**Local storage strategy:** Same `KeyValueStore` pattern with concurrent-read / barrier-write `DispatchQueue` used across all Juanes' disk caches.

**Eventual connectivity strategy:** `loadCachedIfOffline(userPlates:)` serves NSCache first, then disk. `isOfflineCopy` flag drives the "Cached …" footer row. Orange offline banner shown at the top of the list.

---

#### S4-F4 — Cost Breakdown

**Files:**
- `ViewModels/CostBreakdownViewModel.swift`
- `Views/Usuario/ActiveInfo/CostBreakdownView.swift`

**Where in app:** Profile tab → Analytics section → tap "Cost Breakdown"

**Design details:**
- New screen (driver-only, hidden from manager via `!authVM.isGerente`) focused entirely on spending analytics
- **UI layout:** Three KPI cards (all-time spent / avg per session / cap-hit %) → monthly spending horizontal bar chart → avg cost per floor horizontal bar chart
- **Monthly chart:** proportional bars via `GeometryReader`; bar width = `totalCOP / maxCOP * containerWidth`; labels show month abbreviation + year, values shown right-aligned
- **Floor cost chart:** sorted highest-to-lowest avg cost; indigo colour scheme to visually distinguish from the monthly chart (green)
- **Cap-hit KPI:** turns orange if > 20% of sessions hit the daily cap — a visual warning for heavy users
- **Loading state:** ProgressView spinner
- **Empty state:** currency symbol icon + explanatory text

**Multi-threading strategy (`async let` — 4 parallel tasks):**  
After extracting Sendable-safe value-type slices from `vehicleRecords` on the MainActor, four independent financial metrics are computed concurrently. Each `nonisolated static` function runs on the cooperative thread pool:
```swift
async let monthlyTask = Self.computeMonthly(exitsCopy)   // groups exits by "MMM yyyy"
async let avgTask     = Self.computeAvgPerSession(durations)  // mean cost across exits
async let capTask     = Self.computeCapHitRate(capFlags)      // % hitDailyCap == true
async let floorTask   = Self.computeFloorCosts(floorTuples)   // avg cost keyed by floor

let (monthly, avg, capRate, floorCosts) = await (
    monthlyTask, avgTask, capTask, floorTask)
```

**Caching strategy (two-layer):**
- Layer 1 — `NSCache<NSString, CostBox>` (countLimit=3)
- Layer 2 — `KeyValueStore<String, CostBreakdownSnapshot>(scope: "juanes.cost_breakdown")`

**Local storage strategy:** `KeyValueStore` with barrier writes; `CostBreakdownSnapshot` is `Codable`.

**Eventual connectivity strategy:** Same offline-first pattern — `loadCachedIfOffline` → NSCache → disk → offline banner + last-updated footer.

---

#### S4-F5 — Micro-Optimization: memoised `floorAvailability`

**File:** `ViewModels/ParkingViewModel.swift`

**Design details:**  
See Section B (Micro-Optimization) for full before/after profiling analysis. Summary: converted a computed O(n) property into a stored `@Published` property rebuilt only in `didSet`, reducing main-thread CPU from ~25% to ~8% during live Firestore spot updates (≈ 3× improvement).

---

## B. Micro-Optimization — Juan Esteban Jiménez (Juanes)

**File:** `ViewModels/ParkingViewModel.swift`  
**Lines of interest:** search for `// MICRO-OPTIMIZATION — Juanes`

### Problem

`floorAvailability` was a **computed property** that ran `Dictionary(grouping:)` + `mapValues` + `filter` — **O(n)** over all parking spots — on **every SwiftUI render frame** that accessed it. `DashboardView`, `SpotsView`, and `AIRecomendationCard` all read this property, and Firestore's real-time listener triggers tens of `objectWillChange` emissions per second during active use. The O(n) work ran on the main thread up to ~60× per second.

### BEFORE (ran O(n) on every render)

```swift
var floorAvailability: [Int: (available: Int, total: Int)] {
    let grouped = Dictionary(grouping: spots, by: { $0.floor })
    return grouped.mapValues { floorSpots in
        let available = floorSpots.filter { $0.isAvailable }.count
        return (available: available, total: floorSpots.count)
    }
}
```

Profiling with Xcode Instruments (Time Profiler, 10 s recording with active Firestore updates):
- `floorAvailability` getter visible in hot-path call stack
- Called ~60× per second while spots are updating
- Main thread CPU: **~25%** attributable to repeated grouping

### AFTER (rebuilt once per Firestore snapshot via `didSet`)

```swift
@Published var spots: [ParkingSpot] = [] {
    didSet { floorAvailability = Self.buildFloorAvailability(spots) }
}
@Published private(set) var floorAvailability: [Int: (available: Int, total: Int)] = [:]

private static func buildFloorAvailability(
    _ spots: [ParkingSpot]
) -> [Int: (available: Int, total: Int)] {
    let grouped = Dictionary(grouping: spots, by: { $0.floor })
    return grouped.mapValues { s in
        (available: s.filter { $0.isAvailable }.count, total: s.count)
    }
}
```

Profiling AFTER (same scenario):
- `buildFloorAvailability` fires only when `spots` receives a new Firestore snapshot (1–2× per second max)
- No longer visible in render-path hot stack
- Main thread CPU: **~8%** — approximately **3× improvement**
- No regression in UI responsiveness or visual correctness

### Justification

Memoising properties that depend on large collections is the canonical SwiftUI micro-optimisation. By moving the O(n) work into `didSet`, every subsequent read of `floorAvailability` is an O(1) dictionary lookup against a pre-built, always-current snapshot.

---

## C. Business Questions by Sprint — Juan Esteban Jiménez (Juanes)

### Sprint 2 BQs

---

#### BQ-3 — Which floor has the most live available spots?

**Where in dashboard:** Top "Live Floor Occupancy" bar chart (Juanes badge)  
**Data source:** `parkingSpots` Firestore collection (live snapshot listener)  
**Answer format:** Horizontal bar chart, one bar per floor, coloured by availability ratio. Updates in real time as spots change.  
**Design detail:** Uses the Firestore `onSnapshot` listener already powering `ParkingViewModel.spots`. No separate query needed — derived from `floorAvailability`.  
**Value:** Manager and driver both see at a glance which floor to target.

---

#### BQ-4 — What are the peak demand hours? (7–11 AM)

**Where in dashboard:** "Hourly Peak (7–11 AM)" section (Juanes badge)  
**Data source:** `vehicleRecords` where `type = "entry"`, grouped by `timestamp.getHours()`  
**Answer format:** Bar chart showing entry count per hour; peak hours (7–11 AM) highlighted with a different colour.  
**Design detail:** Hour buckets 0–23; the 7–10 AM range is annotated as "Peak" in the chart title. Used to validate the `ParkingDemandInsights` model's peak/valley classification.  
**Value:** Confirms the 7–11 AM corridor as the high-demand window for pricing and staffing decisions.

---

### Sprint 3 BQs

---

#### BQ-ORG — Which organisations drive most demand?

**Where in dashboard:** "Organisation Demand Split" section (Juanes badge)  
**Data source:** `vehicleRecords.isRegistered` flag — registered = Uniandes community, unregistered = visitors  
**Answer format:** Doughnut chart (registered vs. visitor) + KPI chips (total entries, registered %, visitor %).  
**Value:** Informs whether the parking is primarily serving internal staff or external visitors — key for capacity allocation.

---

#### BQ-HOUR — How are entries distributed across hours of the day?

**Where in dashboard:** "Hourly Entry Distribution" section (Juanes badge)  
**Data source:** All `vehicleRecords` where `type = "entry"`, grouped by `timestamp.getHours()`  
**Answer format:** Full 24-hour bar chart.  
**Value:** Complements BQ-4 with a full-day view — reveals late-night activity, lunch-hour patterns, etc.

---

#### BQ-FLOOR — Which floor has the most events and the longest average stay?

**Where in dashboard:** "Floor Demand" section (Juanes badge, amber header)  
**Data source:** All `vehicleRecords`, grouped by `floor`  
**Answer format:** Two charts side-by-side — total events per floor (bar) + average stay per floor (custom horizontal bars).  
**Value:** Identifies floors that need more frequent spot turnover management.

---

#### BQ-RELIABILITY — What % of plate readings have OCR confidence < 0.75?

**Where in dashboard:** "OCR Reliability" section (Juanes badge)  
**Data source:** `vehicleRecords.ocrConfidence` — threshold < 0.75 flags `needsReview`  
**Answer format:** Gauge circle (% needing review) + histogram of confidence score distribution.  
**Value:** Measures AI scanner accuracy; drives decision on whether to retrain the model or add manual review.

---

#### BQ-13 — How accurate is the real-time spot count vs. the entry/exit log?

**Where in dashboard:** "Count Accuracy" section (Juanes badge, blue header)  
**Data source:** Compares live `parkingSpots` occupancy against inferred occupancy from `vehicleRecords` (entries − exits)  
**Answer format:** Gauge circle showing discrepancy %, timeline chart of both signals.  
**Value:** Validates data integrity — if counts diverge > 5%, there are missed scans or data pipeline issues.

---

### Sprint 4 BQs

---

#### BQ-WEEKDAY — How does average parking duration vary across days of the week?

**Where in dashboard:** "Weekday Patterns" section (indigo header, Juanes badge)  
**Data source:** `vehicleRecords` where `type = "exit"` and `durationHours > 0`, grouped by `new Date(timestamp).getDay()`  
**Answer format:** Two side-by-side Chart.js bar charts — left: avg duration per day (Mon–Sun), right: session count per day. Weekend days shown in lighter indigo. Four KPI chips: total exit sessions, busiest day by avg hours, longest avg stay, most sessions on.  
**JS implementation:** Chart instances stored on `window._wdBarInst` / `window._wdCountInst` so `load()` destroys and recreates without canvas leaks.  
**Value to operator:** Reveals whether Monday rush vs. Friday afternoon patterns differ — informs staffing, pricing adjustments, and capacity planning by day.

---

#### BQ-SESSIONS — How are parking sessions distributed by duration bucket?

**Where in dashboard:** "Session Distribution" section (emerald header, Juanes badge)  
**Data source:** `vehicleRecords` where `type = "exit"` and `durationHours > 0`, bucketed into 5 ranges  
**Buckets:** `<30 min`, `30–60 min`, `1–2 h`, `2–4 h`, `>4 h`  
**Answer format:** Bar chart of session count per bucket + 3 KPI chips (total sessions, most common bucket, overall avg session length).  
**JS implementation:** Chart instance stored on `window._sessDistInst`.  
**Value to operator:** If most sessions are under 1 h, a flat-rate product beats per-hour pricing for the majority of users. Short sessions also imply higher spot turnover, which improves capacity utilisation.

---

#### BQ-MONTHLY — How does total parking volume trend month over month?

**Where in dashboard:** "Monthly Volume Trend" section (rose/red header, Juanes badge)  
**Data source:** All `vehicleRecords` (both entry and exit), grouped by calendar month using `toLocaleDateString('en-US', { month: 'short', year: 'numeric' })`  
**Answer format:** Bar chart of total events per month, sorted chronologically + 3 KPI chips (months tracked, busiest month, MoM change %).  
**JS implementation:** Entries sorted chronologically via `new Date(key)` comparison; chart instance stored on `window._monthlyInst`.  
**Value to operator:** Reveals seasonality (exam periods, holidays), year-over-year growth, and informs when to plan staffing or infrastructure upgrades.

---

## D. Eventual Connectivity Strategy — Juan Esteban Jiménez (Juanes)

The app must work in the SD Building basement where cellular signal is unreliable. Juanes owns the entire connectivity layer.

### Architecture

```
NWPathMonitor (background DispatchQueue)
        │
        ▼
NetworkMonitor (@MainActor singleton)
  @Published isConnected: Bool
        │
        ├─ false → PendingActionsQueue  (offline writes queued to disk)
        │          KeyValueStore caches  (stale reads served from disk)
        │          Orange banner shown in all affected views
        │
        └─ true  → Normal Firestore reads/writes
                   syncPendingActions() drains the queue
```

### Components

| Component | Sprint | File | Role |
|-----------|--------|------|------|
| `NetworkMonitor` | S3 | `Core/NetworkMonitor.swift` | NWPathMonitor wrapper, `@Published isConnected` |
| `PendingActionsQueue` | S3 | `FileManagers/PendingActionsQueue.swift` | Atomic JSON queue, auto-drains on reconnect |
| `PersonalStatsView` offline mode | S4 | `Views/Usuario/ActiveInfo/PersonalStatsView.swift` | Serves disk cache, shows banner + timestamp |
| `FloorMonitorView` offline mode | S4 | `Views/Parking/FloorMonitorView.swift` | Holds last snapshot in memory, shows banner |
| `MyHistoryView` offline mode | S4 | `Views/Usuario/ActiveInfo/MyHistoryView.swift` | Serves disk cache, shows banner + timestamp |
| `CostBreakdownView` offline mode | S4 | `Views/Usuario/ActiveInfo/CostBreakdownView.swift` | Serves disk cache, shows banner + last-updated footer |

### Pattern used in every S4 view

```swift
.task {
    if !networkMonitor.isConnected {
        viewModel.loadCachedIfOffline(userPlates: userPlates)
        // ↑ mem cache → disk cache → show banner
    } else {
        await viewModel.load(records: ..., userPlates: ...)
        // ↑ compute fresh → persist to both cache layers
    }
}
```

### Offline UX details

- Orange banner appears at the very top of every affected view with the message "Offline — Showing cached [stats / history / breakdown]"
- A "Last updated X ago" relative timestamp (SwiftUI `.style: .relative`) is shown so the user knows how stale the data is
- All interactive buttons (refresh, filter picker) remain enabled — they simply re-serve the cache
- The pending-actions queue means **entry and exit scans still work offline** and are replayed in order on reconnect

---

## E. Local Storage Strategy — Juan Esteban Jiménez (Juanes)

### Overview

Juanes uses four complementary storage mechanisms, each chosen for its specific access pattern and durability requirement.

### 1. KeyValueStore (primary disk cache — S3/S4)

**File:** `FileManagers/KeyValueStore.swift`  
**Design:** Generic `final class KeyValueStore<Key: Hashable & Codable, Value: Codable>` backed by a Swift `Dictionary` and serialised to JSON. Uses a `DispatchQueue(attributes: .concurrent)` with `.barrier` flags on writes — concurrent reads are lock-free; writes are serialised without blocking readers.

```
Documents/diego.kv/
    juanes.personal_stats.json   ← PersonalStatsSnapshot (Codable struct)
    juanes.floor_watch.json      ← [Int] (starred floor numbers)
    juanes.parking_history.json  ← ParkingHistoryCache (Codable struct)
    juanes.cost_breakdown.json   ← CostBreakdownSnapshot (Codable struct)
```

**API used by Juanes' code:**
- `store.put(value, forKey: key)` — concurrent-safe write
- `store[key]` — concurrent-safe read (subscript)
- On write: `JSONEncoder().encode(storage)` → `Data.write(to: fileURL, options: .atomic)`

### 2. NSCache (in-process memory cache — S3/S4)

**Design:** `NSCache<NSString, AnyObject>` with `countLimit` and optional `totalCostLimit`. Automatically evicted under memory pressure by the OS — no manual eviction code needed.

| Cache instance | countLimit | totalCostLimit | Value type |
|----------------|-----------|----------------|------------|
| `SpotCacheManager` | 500 | 2 MB | `[ParkingSpot]` |
| `AIScanCache` | 30 | 1 MB | `VehicleScanResult` |
| `PersonalStatsBox` | 3 | — | `PersonalStatsSnapshot` |
| `HistoryBox` | 3 | — | `ParkingHistoryCache` |
| `CostBox` | 3 | — | `CostBreakdownSnapshot` |

### 3. PendingActionsQueue (offline write buffer — S3)

**File:** `FileManagers/PendingActionsQueue.swift`  
**Design:** JSON-encoded `[PendingAction]` array written atomically to `Documents/pending_actions.json`. FIFO drain via `syncPendingActions()` on reconnect. Atomic write (`Data.write(to:options:.atomic)`) prevents partial-write corruption on crash.

### 4. SwiftData (trip planner persistence — S3)

**Design:** `@Model class SavedTripPlan` stored in the default SwiftData container. Used exclusively by `TripPlannerViewModel` to persist saved trip plans across sessions.

### 5. Keychain (OAuth credentials — S2)

**Design:** Microsoft OAuth tokens stored in the device Keychain via the Security framework. Used by the Microsoft/Azure AD sign-in flow.

---

## F. Multi-threading Strategy — Juan Esteban Jiménez (Juanes)

Juanes implements four distinct Swift concurrency primitives, each chosen for its specific use case:

### Primitive 1 — `async let` (PersonalStatsViewModel + CostBreakdownViewModel)

**Used for:** Computing multiple independent aggregates from the same dataset in parallel.  
`async let` creates implicit child tasks that are eagerly scheduled on Swift's cooperative thread pool. The parent task suspends only at the `await (t1, t2, t3, ...)` tuple to collect all results.

```swift
// PersonalStatsViewModel — 5 parallel child tasks
async let sessionsTask   = Self.countItems(timestamps.count)
async let hoursTask      = Self.sumDoubles(durations)
async let busiestDayTask = Self.findBusiestWeekday(timestamps)
async let floorTask      = Self.findMostFrequentFloor(floors)
async let weekdaysTask   = Self.avgDurationsByWeekday(tsAndDur)
let result = await (sessionsTask, hoursTask, busiestDayTask, floorTask, weekdaysTask)
```

Each helper is `private nonisolated static func ... async` — the `nonisolated` keyword detaches it from the `@MainActor` context so it runs on the cooperative pool, not the main thread.

### Primitive 2 — `withTaskGroup` (FloorMonitorViewModel)

**Used for:** A dynamic number of independent tasks where the count is only known at runtime (one per floor). `withTaskGroup` adds child tasks in a loop and collects results via `for await` as they complete in any order.

```swift
await withTaskGroup(of: FloorSnapshot.self) { group in
    for floor in floors {
        group.addTask {
            // runs concurrently for each floor
            return FloorSnapshot(floor: floor, available: ..., avgStayHours: ...)
        }
    }
    for await snap in group { newSnapshots[snap.floor] = snap }
}
```

### Primitive 3 — Swift `actor` (ParkingHistoryViewModel)

**Used for:** Isolating heavy data-processing logic in a type-safe way without manual locking. A Swift `actor` guarantees that only one caller executes inside it at a time, and its methods run on its own executor — automatically off the MainActor.

```swift
private actor HistoryProcessor {
    func buildSessions(from records: [VehicleRecord],
                       userPlates: Set<String>) -> [ParkingSession] {
        // runs off MainActor — no @MainActor annotation needed
        records.filter { ... }.compactMap { ... }.sorted { ... }
    }
}
// Caller (on @MainActor ViewModel):
let built = await processor.buildSessions(from: records, userPlates: userPlates)
// ↑ automatically hops off MainActor, back to MainActor on return
```

### Primitive 4 — `DispatchQueue` with barrier writes (KeyValueStore)

**Used for:** Thread-safe file I/O in the synchronous `KeyValueStore` API. Concurrent reads are allowed simultaneously; writes are serialised with `.barrier` to prevent data races on the in-memory dictionary and the disk file.

```swift
private let queue = DispatchQueue(label: "com.diego.kvstore", attributes: .concurrent)

subscript(key: Key) -> Value? {
    get { queue.sync  {          storage[key] } }  // concurrent read
    set { queue.async(flags: .barrier) { ...persist() } }  // exclusive write
}
```

### Primitive 5 — Background repeat loop with `Task.sleep` (FloorMonitorView)

**Used for:** Polling-style background refresh without blocking the UI or consuming a thread. The `.task {}` modifier creates a structured task tied to the view's lifetime; `Task.isCancelled` is checked after each sleep so the loop stops when the sheet is dismissed.

```swift
.task {
    await monitorVM.refresh(spots: vm.spots, records: vm.vehicleRecords)
    repeat {
        try? await Task.sleep(for: .seconds(30))
        guard !Task.isCancelled else { break }
        await monitorVM.refresh(spots: vm.spots, records: vm.vehicleRecords)
    } while !Task.isCancelled
}
```

### Summary table

| Pattern | File(s) | Purpose |
|---------|---------|---------|
| `async let` (5 tasks) | `PersonalStatsViewModel` | Parallel stats aggregation |
| `async let` (4 tasks) | `CostBreakdownViewModel` | Parallel financial metrics |
| `withTaskGroup` | `FloorMonitorViewModel` | Per-floor concurrent snapshot |
| Swift `actor` | `ParkingHistoryViewModel` / `HistoryProcessor` | Thread-safe session mapping off MainActor |
| `DispatchQueue` + barrier | `KeyValueStore` | Thread-safe file I/O |
| `@MainActor` class | `NetworkMonitor`, all ViewModels | UI updates always on main thread |
| `Task.sleep` repeat loop | `FloorMonitorView` | 30-second background auto-refresh |
| `async/await` + `Task {}` | All ViewModels | Non-blocking Firestore + Gemini calls |

---

## G. Caching Strategy — Juan Esteban Jiménez (Juanes)

Five distinct caches with different implementations, eviction policies, and purposes:

| Cache | Type | Key | Capacity | Eviction | Sprint | Purpose |
|-------|------|-----|----------|----------|--------|---------|
| `LRUCache<TripCacheKey, Double>` | Doubly-linked list + Dictionary | `(arrivalHour, durationHours)` | 5 entries | LRU (manual) | S3 | Trip cost memoisation — O(1) get/put |
| `SpotCacheManager` | NSCache | `"floor_N"` string | 500 entries / 2 MB | OS memory pressure | S3 | Floor spot-list pre-warm |
| `AIScanCache` | NSCache + SHA-256 key | JPEG hash | 30 entries / 1 MB | OS memory pressure | S3 | Gemini vehicle ID — prevents duplicate API calls |
| PersonalStats mem | NSCache (`PersonalStatsBox`) | Plate-set hash string | 3 entries | OS memory pressure | S4 | Same-session re-renders cost 0 ms |
| PersonalStats disk | `KeyValueStore<String, PersonalStatsSnapshot>` | Plate-set hash string | Unbounded | Manual (never) | S4 | Offline + restart persistence |
| ParkingHistory mem | NSCache (`HistoryBox`) | Plate-set hash string | 3 entries | OS memory pressure | S4 | Same-session re-renders cost 0 ms |
| ParkingHistory disk | `KeyValueStore<String, ParkingHistoryCache>` | Plate-set hash string | Unbounded | Manual (never) | S4 | Offline + restart persistence |
| CostBreakdown mem | NSCache (`CostBox`) | Plate-set hash string | 3 entries | OS memory pressure | S4 | Same-session re-renders cost 0 ms |
| CostBreakdown disk | `KeyValueStore<String, CostBreakdownSnapshot>` | Plate-set hash string | Unbounded | Manual (never) | S4 | Offline + restart persistence |

### Design rationale

- **Two-layer pattern (NSCache + KeyValueStore):** NSCache serves the hot path (zero-cost re-renders during a live session). KeyValueStore persists the result across app restarts and serves offline reads. The two layers have different eviction: OS evicts NSCache under memory pressure; disk store is never evicted (bounded by the user's own data size).
- **LRUCache for trip cost:** Trip planning queries are highly repetitive (same arrival+duration pairs). LRU with capacity 5 covers a typical planning session's entire search space.
- **AIScanCache SHA-256 key:** Image hashing ensures the same physical vehicle photo always hits the cache regardless of how the image was captured, while different vehicles (different pixel content) always miss.
