//
//  ColombianPlateValidator.swift
//  sd-smart-parking
//

import Foundation

// MARK: - Strategy protocol

struct PlateMatch {
    let plate: String      // normalized, e.g. "ABC123"
    let confidence: Float  // from VNRecognizedText.confidence
}

protocol PlateValidationStrategy {
    /// Finds the first plate matching this strategy's format among OCR candidates.
    func findPlate(in candidates: [(text: String, confidence: Float)]) -> PlateMatch?
}

// MARK: - Colombian plate strategy (ABC123)

struct ColombianPlateStrategy: PlateValidationStrategy {
    private static let regex = try! NSRegularExpression(pattern: "^[A-Z]{3}[0-9]{3}$")

    /// Characters that Vision may detect at the separator position on Colombian plates
    /// (raised dot between letters and digits). Strip before matching.
    private static let separators = CharacterSet(charactersIn: ".-·•–—")
        .union(.whitespaces)
        .union(.punctuationCharacters)

    func findPlate(in candidates: [(text: String, confidence: Float)]) -> PlateMatch? {
        for candidate in candidates {
            let stripped = candidate.text
                .uppercased()
                .components(separatedBy: ColombianPlateStrategy.separators)
                .joined()

            let range = NSRange(stripped.startIndex..., in: stripped)
            if ColombianPlateStrategy.regex.firstMatch(in: stripped, range: range) != nil {
                return PlateMatch(plate: stripped, confidence: candidate.confidence)
            }
        }
        return nil
    }
}

// MARK: - Convenience free function (keeps call sites simple)

/// Default strategy: Colombian plates.
func findColombianPlate(in candidates: [(text: String, confidence: Float)]) -> PlateMatch? {
    ColombianPlateStrategy().findPlate(in: candidates)
}
