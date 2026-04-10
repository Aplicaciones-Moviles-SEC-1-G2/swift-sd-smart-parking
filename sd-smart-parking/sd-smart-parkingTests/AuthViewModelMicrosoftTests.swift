//
//  AuthViewModelMicrosoftTests.swift
//  sd-smart-parkingTests
//

import Foundation
import Testing
@testable import sd_smart_parking

// MARK: - Mock

private class MockMicrosoftOAuth: MicrosoftOAuthProviding {
    var errorToThrow: Error?
    var signInCalled = false

    func signIn() async throws {
        signInCalled = true
        if let error = errorToThrow { throw error }
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
