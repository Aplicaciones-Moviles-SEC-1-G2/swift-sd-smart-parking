---
feature: ai-vehicle-scan
type: smart
status: research
---

# Research: AI Vehicle Scan

## Context
Gerente-facing feature that takes a single photo of a car and asks Gemini
(`gemini-2.5-flash-lite`, the fastest Gemini flavor) to return the license
plate, color, brand, and model. If the plate is not visible in the frame the
rest of the fields are still returned along with a "plate not visible" notice.
Distinct from the existing `smart-license-plate-ocr` feature, which uses
on-device Apple Vision to read plates only.

## Relevant files

| Path | Role | How the feature interacts |
|---|---|---|
| `sd-smart-parking/Secrets.swift` | Stores `Secrets.apiKey` | Reused as the Gemini API key |
| `sd-smart-parking/ViewModels/aiVM.swift` | Existing Gemini call reference | Matches pattern: `GenerativeModel(name:apiKey:safetySettings:)`, `gemini-2.5-flash-lite` |
| `sd-smart-parking/Views/Gerente/PlateOCRScannerView.swift` | Existing Vision-based plate sheet | Sits next to the new AI sheet in `CreateRecordView` |
| `sd-smart-parking/Views/Gerente/CreateRecordView.swift` | Host form | Adds the new "AI Scan Vehicle" button and consumes the result |
| `sd-smart-parking/Info.plist` | `NSCameraUsageDescription` already present | No Info.plist changes needed |
| `sd-smart-parking/Models/Car.swift` | Existing driver-owned car model | Unrelated — distinct from identification results |

## How they work
- `aiVM.swift` uses `GoogleGenerativeAI` (already in SPM) to call Gemini with a
  text prompt and parse `response.text`. Safety settings are relaxed to avoid
  traffic-related false blocks.
- `PlateOCRScannerView.swift` is a `UIViewRepresentable` on top of
  `AVCaptureSession` + `AVCapturePhotoOutput`, running `VNRecognizeTextRequest`
  on captured photos and validating candidates through
  `ColombianPlateValidator`.
- `CreateRecordView.swift` already uses `.sheet` to present the plate OCR
  scanner and receive a `(String, Double)` callback.

## Similar patterns in repo
- **MVVM with `ObservableObject` + `@Published`** (every ViewModel).
- **Firebase/Gemini SDK calls live inside ViewModels** — no service layer.
- **Sheet-based capture flows** (`PlateOCRSheet`) with callback on completion.
- **Spanish-named managerial views** (`Gerente/`) — new file sits there.

## Open questions
- Camera bridge: reuse `AVCaptureSession` like `PlateOCRCameraView`, or use
  `UIImagePickerController`? → Picker chosen for simplicity and simulator
  fallback to photo library, keeping the feature testable without a device.
- JSON contract reliability: Gemini is instructed to return strict JSON and
  configured with `responseMIMEType = "application/json"`. A defensive
  fence-stripping step guards against accidental markdown wrapping.
- Persist color/brand/model in `VehicleRecord`? → Out of scope for this
  feature; VM fills only the plate when visible and surfaces the AI details
  inline for the operator to read.
