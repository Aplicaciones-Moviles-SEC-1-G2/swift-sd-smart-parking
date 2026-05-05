//
//  VehicleAIScannerViewModel.swift
//  sd-smart-parking
//
//  Uses Gemini to extract plate/brand/model/color from a car photo.
//

import SwiftUI
import Combine
import GoogleGenerativeAI

@MainActor
class VehicleAIScannerViewModel: ObservableObject {

    enum ScanState: Equatable {
        case idle
        case analyzing
        case success(VehicleIdentification)
        case failure(String)
    }

    @Published var state: ScanState = .idle

    private let model: GenerativeModel

    init() {
        let safetySettings = [
            SafetySetting(harmCategory: .harassment, threshold: .blockNone),
            SafetySetting(harmCategory: .dangerousContent, threshold: .blockNone)
        ]

        let generationConfig = GenerationConfig(
            temperature: 0.1,
            responseMIMEType: "application/json"
        )

        self.model = GenerativeModel(
            name: "gemini-2.5-flash-lite",
            apiKey: Secrets.apiKey,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
    }

    func analyze(image: UIImage) {
        state = .analyzing
        let prepared = Self.resized(image, maxSide: 1280)
        let preparedJPEG = prepared.jpegData(compressionQuality: 0.7)

        // Cache lookup — saves a Gemini round-trip when the operator re-scans
        // the exact same vehicle photo (same JPEG bytes -> same SHA256 key).
        let cacheKey = preparedJPEG.map { AIScanCache.key(forJPEGData: $0) }
        if let key = cacheKey, let cached = AIScanCache.shared.get(key) {
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

                // Cache write — only if we have a stable key and JPEG bytes.
                if let key = cacheKey, let data = preparedJPEG {
                    AIScanCache.shared.put(identification, for: key, cost: data.count)
                }

                // Append to local scan history (Codable + FileManager). Best-effort
                // write — failures don't surface to the user. Reuses the same
                // SHA256 hex string the cache key already derived from the bytes.
                let hashHex = (cacheKey as String?) ?? ""
                ScanHistoryStore.shared.append(
                    ScanHistoryEntry(identification: identification, imageHashHex: hashHex)
                )
            } catch let decodingError as VehicleAIScannerError {
                self.state = .failure(decodingError.message)
            } catch {
                self.state = .failure("AI error: \(error.localizedDescription)")
            }
        }
    }

    func reset() {
        state = .idle
    }

    // MARK: - Helpers

    private static let prompt = """
    You are analyzing a photo of a vehicle. Respond ONLY with a single JSON object
    that matches this exact schema (no markdown, no commentary):

    {
      "plateVisible": boolean,   // true only if a license plate is clearly readable
      "plate": string | null,    // plate text in UPPERCASE, letters/digits only, no spaces or separators; null when plateVisible is false
      "color": string,           // dominant exterior color in lowercase English (e.g. "white", "black", "red")
      "brand": string,           // manufacturer (e.g. "Toyota", "Mazda"). Use "unknown" if you cannot tell.
      "model": string            // model name (e.g. "Corolla", "3"). Use "unknown" if you cannot tell.
    }

    If the photo does not contain a vehicle, set plateVisible=false, plate=null,
    and fill color/brand/model with "unknown".
    """

    private static func decode(_ raw: String) throws -> VehicleIdentification {
        let cleaned = stripJSONFences(raw)
        guard let data = cleaned.data(using: .utf8) else {
            throw VehicleAIScannerError(message: "AI response was not valid text.")
        }
        do {
            return try JSONDecoder().decode(VehicleIdentification.self, from: data)
        } catch {
            throw VehicleAIScannerError(message: "Could not parse the AI response.")
        }
    }

    private static func stripJSONFences(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let firstNewline = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: firstNewline)...])
            }
            if t.hasSuffix("```") {
                t = String(t.dropLast(3))
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

private struct VehicleAIScannerError: Error {
    let message: String
}
