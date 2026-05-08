//
//  AuthViewModelMicrosoftTests.swift
//  sd-smart-parkingTests
//

import Foundation
import Testing
@testable import sd_smart_parking

// MARK: - Mocks

private class MockMicrosoftOAuth: MicrosoftOAuthProviding {
    var errorToThrow: Error?
    var signInCalled = false

    func signIn() async throws {
        signInCalled = true
        if let error = errorToThrow { throw error }
    }
}

/// Local in-memory keychain so signOut tests don't pollute the real keychain.
private final class InMemoryKeychain: KeychainStoring {
    private var storage: [String: Data] = [:]
    private func key(_ account: String, _ service: String) -> String { "\(service)|\(account)" }

    @discardableResult
    func set(_ data: Data, account: String, service: String) -> Bool {
        storage[key(account, service)] = data
        return true
    }

    func get(account: String, service: String) -> Data? {
        storage[key(account, service)]
    }

    @discardableResult
    func delete(account: String, service: String) -> Bool {
        storage.removeValue(forKey: key(account, service))
        return true
    }
}

// MARK: - Tests

@Suite("signInWithMicrosoft")
struct MicrosoftSignInTests {

    @Test func errorSetsErrorMessageAndClearsLoading() async {
        let mock = MockMicrosoftOAuth()
        mock.errorToThrow = NSError(domain: "test", code: 1)
        let vm = AuthViewModel(microsoftOAuth: mock)

        await vm.signInWithMicrosoft()

        #expect(vm.errorMessage == "Microsoft Sign-In was cancelled or failed.")
        #expect(vm.isLoading == false)
    }

    @Test func successCallsProvider() async {
        let mock = MockMicrosoftOAuth()
        let vm = AuthViewModel(microsoftOAuth: mock)

        await vm.signInWithMicrosoft()

        #expect(mock.signInCalled == true)
        #expect(vm.errorMessage == nil)
    }

    @Test func doesNotCallFetchUserDataDirectly() async {
        // Verify the method relies on the auth state listener, not a direct
        // fetchUserData call. When the mock succeeds without actually signing
        // into Firebase, isLoggedIn remains false (only the listener sets it).
        let mock = MockMicrosoftOAuth()
        let vm = AuthViewModel(microsoftOAuth: mock)

        await vm.signInWithMicrosoft()

        #expect(vm.isLoggedIn == false)
    }
}

@Suite("signOutClearsKeychain")
@MainActor
struct SignOutKeychainTests {

    @Test func hardSignOut_removesMicrosoftCredentials() async {
        let keychain = InMemoryKeychain()
        MicrosoftKeychain.saveCredentials(uid: "u-123", email: "test@example.com", store: keychain)
        #expect(MicrosoftKeychain.lastEmail(store: keychain) == "test@example.com")

        let vm = AuthViewModel(microsoftOAuth: MockMicrosoftOAuth(), keychain: keychain)
        // Force the hard-logout branch: biometricsEnabled defaults to false on
        // a fresh @AppStorage in the test process, so signOut takes the hard
        // path and clears Microsoft credentials.
        let userRepo = UserRepository()
        vm.signOut(userRepo: userRepo)

        #expect(MicrosoftKeychain.lastEmail(store: keychain) == nil)
    }
}
