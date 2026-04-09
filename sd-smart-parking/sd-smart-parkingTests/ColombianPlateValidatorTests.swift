//
//  ColombianPlateValidatorTests.swift
//  sd-smart-parkingTests
//

import Foundation
import Testing
@testable import sd_smart_parking

// MARK: - Valid plate cases

@Suite("ColombianPlateValidator")
struct ColombianPlateValidatorTests {

    @Test func validStandardPlate() {
        let result = findColombianPlate(in: [("ABC123", 0.95)])
        #expect(result?.plate == "ABC123")
        #expect(result?.confidence == 0.95)
    }

    @Test func validLowercaseNormalized() {
        let result = findColombianPlate(in: [("abc123", 0.90)])
        #expect(result?.plate == "ABC123")
    }

    @Test func validWithSurroundingText() {
        let result = findColombianPlate(in: [
            ("VEHICLE", 0.80),
            ("XYZ789", 0.92),
            ("PARKING", 0.85)
        ])
        #expect(result?.plate == "XYZ789")
        #expect(result?.confidence == 0.92)
    }

    @Test func validFirstMatchReturned() {
        let result = findColombianPlate(in: [("ABC123", 0.90), ("DEF456", 0.95)])
        #expect(result?.plate == "ABC123")
    }

    @Test func validWithWhitespace() {
        let result = findColombianPlate(in: [("ABC 123", 0.90)])
        #expect(result?.plate == "ABC123")
    }

    @Test func validWithDotSeparator() {
        let result = findColombianPlate(in: [("ABC.123", 0.91)])
        #expect(result?.plate == "ABC123")
    }

    @Test func validWithDashSeparator() {
        let result = findColombianPlate(in: [("ABC-123", 0.89)])
        #expect(result?.plate == "ABC123")
    }

    @Test func validWithMiddleDot() {
        let result = findColombianPlate(in: [("ABC·123", 0.87)])
        #expect(result?.plate == "ABC123")
    }

    @Test func validAmongCityAndOtherText() {
        let result = findColombianPlate(in: [
            ("BOGOTÁ", 0.85),
            ("COLOMBIA", 0.80),
            ("ABC·123", 0.92),
            ("D.C.", 0.70)
        ])
        #expect(result?.plate == "ABC123")
        #expect(result?.confidence == 0.92)
    }
}

// MARK: - No-match cases

@Suite("ColombianPlateValidatorNoMatch")
struct ColombianPlateValidatorNoMatchTests {

    @Test func emptyArray() {
        let result = findColombianPlate(in: [])
        #expect(result == nil)
    }

    @Test func noMatchingCandidates() {
        let result = findColombianPlate(in: [("HELLO", 0.90), ("WORLD", 0.85)])
        #expect(result == nil)
    }

    @Test func tooFewLetters() {
        let result = findColombianPlate(in: [("AB1234", 0.90)])
        #expect(result == nil)
    }

    @Test func tooManyLetters() {
        let result = findColombianPlate(in: [("ABCD12", 0.90)])
        #expect(result == nil)
    }

    @Test func digitsFirst() {
        let result = findColombianPlate(in: [("123ABC", 0.90)])
        #expect(result == nil)
    }

    @Test func tooShort() {
        let result = findColombianPlate(in: [("ABC12", 0.90)])
        #expect(result == nil)
    }

    @Test func tooLong() {
        let result = findColombianPlate(in: [("ABC1234", 0.90)])
        #expect(result == nil)
    }
}

// MARK: - Strategy protocol tests

@Suite("PlateValidationStrategy")
struct PlateValidationStrategyTests {

    @Test func colombianStrategyDirectly() {
        let strategy: PlateValidationStrategy = ColombianPlateStrategy()
        let result = strategy.findPlate(in: [("XYZ789", 0.88)])
        #expect(result?.plate == "XYZ789")
        #expect(result?.confidence == 0.88)
    }

    @Test func colombianStrategyNoMatch() {
        let strategy: PlateValidationStrategy = ColombianPlateStrategy()
        let result = strategy.findPlate(in: [("NOT-A-PLATE", 0.90)])
        #expect(result == nil)
    }
}
