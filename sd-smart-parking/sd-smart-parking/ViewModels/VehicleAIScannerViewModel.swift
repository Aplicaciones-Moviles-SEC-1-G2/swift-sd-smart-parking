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
    private let cache: AIScanCache
    private let history: ScanHistoryStore
    private let stats: ScanStats

    /// Dependencies default to the shared singletons in production. Tests
    /// inject fresh instances to keep the cache HIT path deterministic.
    /// Optional + nil-coalesce keeps the default parameter expression out of
    /// a nonisolated synthesized context (the @MainActor `ScanStats.shared`
    /// would otherwise warn under stricter concurrency).
    init(
        cache: AIScanCache? = nil,
        history: ScanHistoryStore? = nil,
        stats: ScanStats? = nil
    ) {
        self.cache = cache ?? .shared
        self.history = history ?? .shared
        self.stats = stats ?? .shared

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
        // Sprint 4 micro-optimization: move the synchronous prep (resize +
        // JPEG encode + SHA256) off the MainActor so the camera sheet doesn't
        // jank during capture. The cache key is computed once and reused by
        // both the lookup and (on MISS) the cache-write path.
        Task.detached(priority: .userInitiated) { [weak self] in
            let prepared = Self.resized(image, maxSide: 1280)
            let preparedJPEG = prepared.jpegData(compressionQuality: 0.7)
            let cacheKey = preparedJPEG.map { AIScanCache.key(forJPEGData: $0) }
            await self?.continueAnalysis(
                prepared: prepared,
                preparedJPEG: preparedJPEG,
                cacheKey: cacheKey
            )
        }
    }

    private func continueAnalysis(
        prepared: UIImage,
        preparedJPEG: Data?,
        cacheKey: NSString?
    ) async {
        if let key = cacheKey, let cached = cache.get(key) {
            state = .success(cached)
            // History + stats must run on HIT too, otherwise re-scanning the
            // same vehicle drops the entry from local history and skews the
            // top-brands counter.
            recordSuccess(cached, hashHex: key as String)
            return
        }

        do {
            let response = try await model.generateContent(prepared, Self.prompt)
            guard let raw = response.text, !raw.isEmpty else {
                state = .failure("The AI returned an empty response. Try again.")
                return
            }
            let identification = try Self.decode(raw)
            state = .success(identification)

            // Cache write — only if we have a stable key and JPEG bytes.
            if let key = cacheKey, let data = preparedJPEG {
                cache.put(identification, for: key, cost: data.count)
            }

            let hashHex = (cacheKey as String?) ?? ""
            recordSuccess(identification, hashHex: hashHex)
        } catch let decodingError as VehicleAIScannerError {
            state = .failure(decodingError.message)
        } catch {
            state = .failure("AI error: \(error.localizedDescription)")
        }
    }

    func reset() {
        state = .idle
    }

    // MARK: - Private

    /// Persists a successful identification into local history (Codable+FileManager)
    /// and brand stats (KeyValueStore). Reused by BOTH cache HIT and Gemini MISS
    /// branches so re-scans keep both stores in sync.
    private func recordSuccess(_ identification: VehicleIdentification, hashHex: String) {
        history.append(
            ScanHistoryEntry(identification: identification, imageHashHex: hashHex)
        )
        stats.increment(brand: identification.brand)
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

    // Pure function — safe to call from a detached background task as part of
    // the Sprint 4 micro-optimization that moves image prep off the MainActor.
    nonisolated private static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
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
