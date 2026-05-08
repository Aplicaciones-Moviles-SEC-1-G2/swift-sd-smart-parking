//
//  KeychainHelper.swift
//  sd-smart-parking
//
//  Minimal wrapper over the Security framework. No third-party packages.
//
//  Stores items under kSecClassGenericPassword with
//  kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly so credentials survive
//  reboots but are NOT backed up to iCloud.
//
//  The KeychainStoring protocol is a justified extraction (per CLAUDE.md):
//  unit tests inject InMemoryKeychain to avoid hitting the real keychain
//  daemon, which would require simulator entitlements and produce flaky
//  shared state across tests.
//

import Foundation
import Security

protocol KeychainStoring {
    @discardableResult
    func set(_ data: Data, account: String, service: String) -> Bool
    func get(account: String, service: String) -> Data?
    @discardableResult
    func delete(account: String, service: String) -> Bool
}

enum KeychainHelper {
    /// Default singleton wired to the real Security framework. Tests use
    /// InMemoryKeychain instead.
    static let live: KeychainStoring = LiveKeychain()
}

// MARK: - Live implementation

private struct LiveKeychain: KeychainStoring {

    func set(_ data: Data, account: String, service: String) -> Bool {
        // Add does not update; delete first to make set behave as upsert.
        _ = delete(account: account, service: service)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func get(account: String, service: String) -> Data? {
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
    func delete(account: String, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - Convenience constants for the Microsoft sign-in flow

enum MicrosoftKeychain {
    static let service = "com.sdparking.microsoft"
    static let accountUID = "uid"
    static let accountEmail = "email"

    static func saveCredentials(uid: String, email: String, store: KeychainStoring = KeychainHelper.live) {
        if let uidData = uid.data(using: .utf8) {
            store.set(uidData, account: accountUID, service: service)
        }
        if let emailData = email.data(using: .utf8) {
            store.set(emailData, account: accountEmail, service: service)
        }
    }

    static func lastEmail(store: KeychainStoring = KeychainHelper.live) -> String? {
        guard let data = store.get(account: accountEmail, service: service) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clearCredentials(store: KeychainStoring = KeychainHelper.live) {
        store.delete(account: accountUID, service: service)
        store.delete(account: accountEmail, service: service)
    }
}
