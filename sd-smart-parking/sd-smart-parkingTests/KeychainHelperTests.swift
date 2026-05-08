//
//  KeychainHelperTests.swift
//  sd-smart-parkingTests
//
//  Unit-tests the KeychainStoring abstraction against an InMemoryKeychain.
//  We deliberately do NOT exercise the real Security framework here — that
//  would require simulator entitlements and would leak state across tests.
//  Manual verification against the live keychain happens via simctl reboot.
//

import Foundation
import Testing
@testable import sd_smart_parking

private final class InMemoryKeychain: KeychainStoring {
    private struct Key: Hashable { let account: String; let service: String }
    private var items: [Key: Data] = [:]

    func set(_ data: Data, account: String, service: String) -> Bool {
        items[Key(account: account, service: service)] = data
        return true
    }

    func get(account: String, service: String) -> Data? {
        items[Key(account: account, service: service)]
    }

    @discardableResult
    func delete(account: String, service: String) -> Bool {
        items.removeValue(forKey: Key(account: account, service: service)) != nil
    }
}

@Suite("KeychainHelper / InMemoryKeychain")
struct KeychainHelperTests {

    @Test func setThenGetReturnsSameBytes() async throws {
        let store = InMemoryKeychain()
        let payload = Data("hello".utf8)
        #expect(store.set(payload, account: "uid", service: "svc.a"))
        #expect(store.get(account: "uid", service: "svc.a") == payload)
    }

    @Test func setOverwritesExistingValue() async throws {
        let store = InMemoryKeychain()
        _ = store.set(Data("first".utf8), account: "uid", service: "svc.a")
        _ = store.set(Data("second".utf8), account: "uid", service: "svc.a")
        #expect(store.get(account: "uid", service: "svc.a") == Data("second".utf8))
    }

    @Test func deleteRemovesValue() async throws {
        let store = InMemoryKeychain()
        _ = store.set(Data("x".utf8), account: "uid", service: "svc.a")
        #expect(store.delete(account: "uid", service: "svc.a"))
        #expect(store.get(account: "uid", service: "svc.a") == nil)
    }

    @Test func differentServicesAreIsolated() async throws {
        let store = InMemoryKeychain()
        _ = store.set(Data("alpha".utf8), account: "uid", service: "svc.a")
        _ = store.set(Data("beta".utf8), account: "uid", service: "svc.b")

        #expect(store.get(account: "uid", service: "svc.a") == Data("alpha".utf8))
        #expect(store.get(account: "uid", service: "svc.b") == Data("beta".utf8))
    }
}

@Suite("MicrosoftKeychain")
struct MicrosoftKeychainTests {

    @Test func saveAndRetrieveEmail() async throws {
        let store = InMemoryKeychain()
        MicrosoftKeychain.saveCredentials(
            uid: "diego-uid",
            email: "diego@uniandes.edu.co",
            store: store
        )
        #expect(MicrosoftKeychain.lastEmail(store: store) == "diego@uniandes.edu.co")
    }

    @Test func clearRemovesBothEntries() async throws {
        let store = InMemoryKeychain()
        MicrosoftKeychain.saveCredentials(uid: "u", email: "e@x.com", store: store)
        MicrosoftKeychain.clearCredentials(store: store)
        #expect(MicrosoftKeychain.lastEmail(store: store) == nil)
        #expect(store.get(
            account: MicrosoftKeychain.accountUID,
            service: MicrosoftKeychain.service
        ) == nil)
    }

    @Test func missingEmailReturnsNil() async throws {
        let store = InMemoryKeychain()
        #expect(MicrosoftKeychain.lastEmail(store: store) == nil)
    }
}
