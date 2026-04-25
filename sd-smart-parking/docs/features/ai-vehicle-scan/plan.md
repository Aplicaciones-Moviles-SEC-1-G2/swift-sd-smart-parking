---
feature: ai-vehicle-scan
type: smart
status: planned
---

# Plan: AI Vehicle Scan

## Impact analysis

| File | Change |
|---|---|
| `sd-smart-parking/Models/VehicleIdentification.swift` | **New.** `Codable` struct holding `plate`, `plateVisible`, `color`, `brand`, `model` plus a `hasPlate` helper. |
| `sd-smart-parking/ViewModels/VehicleAIScannerViewModel.swift` | **New.** `ObservableObject` that wraps Gemini `gemini-2.5-flash-lite`, accepts a `UIImage`, returns a decoded `VehicleIdentification`. |
| `sd-smart-parking/Views/Gerente/VehicleAIScannerView.swift` | **New.** Sheet that presents `UIImagePickerController` (camera on device, photo library on simulator), displays results or the "plate not visible" warning, and fires a `onUseResult` callback. |
| `sd-smart-parking/Views/Gerente/CreateRecordView.swift` | Extend form with an "AI Scan Vehicle" button, a summary row showing the AI-returned brand/model/color, and auto-fill of the plate field when visible. |

No changes to `project.pbxproj` (synchronized folders), Firebase config, or
`Info.plist` (`NSCameraUsageDescription` already set).

## Feature implementation plan

1. **Model** — add `VehicleIdentification.swift` decoding the JSON Gemini
   returns. `plate` is optional; `plateVisible` is the authoritative flag
   because Gemini may hallucinate a plate when asked for a non-null string.
2. **ViewModel** — `VehicleAIScannerViewModel`:
   - `GenerativeModel(name: "gemini-2.5-flash-lite", …, generationConfig: .init(temperature: 0.1, responseMIMEType: "application/json"))`
   - Prompt instructs strict JSON shape and lowercase English for the
     color/brand/model fields.
   - `analyze(image:)` resizes to max 1280 px, calls `generateContent`, strips
     optional ```` ```json ```` fences, decodes into `VehicleIdentification`.
   - Published `state` machine: `.idle | .analyzing | .success | .failure`.
3. **View** — `VehicleAIScannerSheet` auto-presents a camera picker; once a
   photo is picked it switches to the analyzing state, then shows a results
   card (plate in monospaced bold, brand/model/color in rows). When
   `plateVisible` is false, the plate row reads "not visible" in orange and a
   header banner calls it out. Buttons: **Retake** (resets and re-opens
   picker) and **Use Result** (fires callback and dismisses).
4. **Integration** — `CreateRecordView` gets:
   - A second button under "Scan Plate" labelled "AI Scan Vehicle" with a
     `sparkles` SF Symbol.
   - A `@State var lastAIIdentification: VehicleIdentification?` to render an
     inline summary beneath the button after a successful scan.
   - A `.sheet(isPresented: $showAIVehicleScanner)` that binds
     `VehicleAIScannerSheet` and copies the plate into the form when visible.

## Testing plan

- No test target exists yet in the repo (per `CLAUDE.md`), so automated tests
  are out of scope for this feature.
- Manual smoke test:
  1. Log in as Gerente.
  2. Open **New Record → AI Scan Vehicle**.
  3. Pick a photo of a car with a readable plate; verify plate, color, brand,
     model populate and the plate auto-fills the form.
  4. Pick a photo without a visible plate; verify the orange "No plate
     visible" banner and that the plate field stays empty.
  5. Pick a photo with no car; verify the response reads `unknown` for brand
     and model and `plateVisible=false`.

## Not in scope

- Persisting brand/color/model in `VehicleRecord` (the `VehicleRecord` schema
  and Firestore collection stay untouched).
- Offline fallback when Gemini is unreachable — the VM surfaces the SDK error
  through `.failure`.
- Making the plate OCR feature share code with this one — the existing Vision
  flow continues to work unchanged.
