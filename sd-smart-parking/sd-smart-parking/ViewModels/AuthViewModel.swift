//
//  AuthViewModel.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import GoogleSignInSwift
import LocalAuthentication

// MARK: - Protocol for testing boundary

protocol MicrosoftOAuthProviding {
    func signIn() async throws
}

struct FirebaseMicrosoftOAuth: MicrosoftOAuthProviding {
    func signIn() async throws {
        let provider = OAuthProvider(providerID: "microsoft.com")
        let credential = try await provider.credential(with: nil)
        try await Auth.auth().signIn(with: credential)
    }
}

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var currentUser: User? = nil
    @Published var isGerente: Bool = false
    @Published var currentUserEmail: String? = nil
    @Published var requiresBiometricUnlock: Bool = false

    @AppStorage("biometricsEnabled") var biometricsEnabled: Bool = false

    // The biometric type available on this device (.faceID, .touchID, or .none)
    var biometricType: LABiometryType {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        return ctx.biometryType
    }

    private let db = Firestore.firestore()
    private let microsoftOAuth: MicrosoftOAuthProviding
    private var authStateListener: AuthStateDidChangeListenerHandle?

    init(microsoftOAuth: MicrosoftOAuthProviding = FirebaseMicrosoftOAuth()) {
        self.microsoftOAuth = microsoftOAuth
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            if let firebaseUser = firebaseUser {
                self.currentUserEmail = firebaseUser.email
                Task { await self.fetchUserData(uid: firebaseUser.uid) }
            } else {
                DispatchQueue.main.async {
                    self.isLoggedIn = false
                    self.isGerente = false
                    self.currentUser = nil
                    self.currentUserEmail = nil
                    // Don't touch requiresBiometricUnlock here — signOut() sets it directly
                }
            }
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Fetch user data from Firestore

    private func fetchUserData(uid: String) async {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()

            if !doc.exists {
                guard let firebaseUser = Auth.auth().currentUser else { return }
                try await db.collection("users").document(uid).setData([
                    "name": firebaseUser.displayName ?? "User",
                    "email": firebaseUser.email ?? "",
                    "role": "driver",
                    "createdAt": Timestamp(),
                    "cars": []
                ])
                await fetchUserData(uid: uid)
                return
            }

            guard let data = doc.data() else { return }

            let name = data["name"] as? String ?? ""
            let email = data["email"] as? String ?? ""
            let role = data["role"] as? String ?? "driver"

            let carsData = data["cars"] as? [[String: Any]] ?? []
            let cars: [Car] = carsData.compactMap { carData in
                guard let plate = carData["plate"] as? String,
                      let name = carData["name"] as? String else { return nil }
                return Car(id: UUID(), plate: plate, UserID: UUID(uuidString: uid) ?? UUID(), name: name)
            }

            let user = User(id: UUID(uuidString: uid) ?? UUID(), name: name, email: email, password: "", cars: cars)

            await MainActor.run {
                self.currentUser = user
                self.isGerente = role == "manager"
                self.isLoggedIn = true
                self.isLoading = false
                // Show biometric lock if the user has opted in
                if self.biometricsEnabled {
                    self.requiresBiometricUnlock = true
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error loading user data."
                self.isLoading = false
            }
        }
    }

    // MARK: - Sign In with Email

    func signIn(username: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            try await Auth.auth().signIn(withEmail: username, password: password)
        } catch {
            await MainActor.run {
                self.errorMessage = firebaseErrorMessage(error)
                self.isLoading = false
            }
        }
    }

    // MARK: - Sign In with Google

    func signInWithGoogle() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            await MainActor.run {
                self.errorMessage = "Could not present Google Sign-In."
                self.isLoading = false
            }
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                await MainActor.run {
                    self.errorMessage = "Google authentication failed."
                    self.isLoading = false
                }
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            try await Auth.auth().signIn(with: credential)
        } catch {
            await MainActor.run {
                self.errorMessage = "Google Sign-In was cancelled or failed."
                self.isLoading = false
            }
        }
    }

    // MARK: - Sign In with Microsoft

    func signInWithMicrosoft() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            try await microsoftOAuth.signIn()
        } catch {
            await MainActor.run {
                self.errorMessage = "Microsoft Sign-In was cancelled or failed."
                self.isLoading = false
            }
        }
    }

    // MARK: - Biometric Sign In (from login screen)

    func signInWithBiometrics() async {
        let context = LAContext()
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Sign in to SD Parking"
            )
            if success {
                if let firebaseUser = Auth.auth().currentUser {
                    await fetchUserData(uid: firebaseUser.uid)
                } else {
                    #if DEBUG
                    await MainActor.run { self.loginAsUser() }
                    #endif
                }
            }
        } catch let error as LAError {
            await MainActor.run {
                switch error.code {
                case .userCancel, .systemCancel, .appCancel:
                    break
                case .biometryNotEnrolled:
                    self.errorMessage = "No biometrics enrolled. Use your password."
                case .biometryLockout:
                    self.errorMessage = "Biometrics locked. Use your password."
                default:
                    self.errorMessage = "Biometric authentication failed."
                }
            }
        } catch {
            await MainActor.run { self.errorMessage = "Biometric authentication failed." }
        }
    }

    // MARK: - Biometric Authentication

    func authenticateWithBiometrics() async {
        let context = LAContext()
        let reason = "Sign in to SD Parking"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if success {
                if let firebaseUser = Auth.auth().currentUser {
                    await fetchUserData(uid: firebaseUser.uid)
                } else {
                    #if DEBUG
                    await MainActor.run {
                        if self._lastGerente {
                            self.loginAsGerente()
                        } else {
                            self.loginAsUser()
                        }
                    }
                    #endif
                }
                await MainActor.run {
                    self.requiresBiometricUnlock = false
                    self.errorMessage = nil
                }
            }
        } catch let error as LAError {
            await MainActor.run {
                switch error.code {
                case .userCancel, .systemCancel, .appCancel:
                    break // user dismissed, no error shown
                case .biometryNotEnrolled:
                    self.errorMessage = "No biometrics enrolled. Use your password instead."
                case .biometryLockout:
                    self.errorMessage = "Biometrics locked. Use your password to unlock."
                default:
                    self.errorMessage = "Biometric authentication failed."
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Biometric authentication failed."
            }
        }
    }

    // MARK: - Register

    func register(name: String, email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid

            // Write the user doc before relying on the auth-state listener so
            // fetchUserData always finds the correct name (fixes the race condition
            // where the listener fires before setData completes).
            try await db.collection("users").document(uid).setData([
                "name": name,
                "email": email,
                "role": "driver",
                "createdAt": Timestamp(),
                "cars": []
            ])

            // Explicitly fetch user data now that the doc is ready — this is
            // what actually sets isLoggedIn = true and navigates into the app.
            await fetchUserData(uid: uid)
        } catch {
            await MainActor.run {
                self.errorMessage = firebaseErrorMessage(error)
                self.isLoading = false
            }
        }
    }

    // MARK: - Sign Out

    @MainActor
    func signOut() {
        let ctx = LAContext()
        var err: NSError?
        let hasBiometrics = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)

        if hasBiometrics && biometricsEnabled {
            // Soft logout: keep Firebase session alive so Face ID can restore it
            _lastGerente = isGerente
            isLoggedIn = false
            requiresBiometricUnlock = true
            errorMessage = nil
        } else {
            try? Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            isLoggedIn = false
            isGerente = false
            currentUser = nil
            currentUserEmail = nil
            requiresBiometricUnlock = false
            errorMessage = nil
        }
    }

    // Stores the last role so biometric re-login can restore it in dev mode
    private var _lastGerente: Bool = false

    // MARK: - Add Car

    func addCar(name: String, plate: String) async {
        guard let uid = Auth.auth().currentUser?.uid,
              var user = currentUser else { return }

        let newCar = Car(id: UUID(), plate: plate, UserID: user.id, name: name)
        user = User(id: user.id, name: user.name, email: user.email, password: "", cars: user.cars + [newCar])

        let carsData = user.cars.map { ["plate": $0.plate, "name": $0.name] }

        do {
            try await db.collection("users").document(uid).updateData(["cars": carsData])
            await MainActor.run { self.currentUser = user }
        } catch {
            await MainActor.run { self.errorMessage = "Error saving car." }
        }
    }

    // MARK: - Update Profile

    func updateProfile(newName: String, newEmail: String) async {
        guard let uid = Auth.auth().currentUser?.uid,
              let current = currentUser else { return }

        do {
            try await db.collection("users").document(uid).updateData([
                "name": newName,
                "email": newEmail
            ])
            let updatedUser = User(id: current.id, name: newName, email: newEmail, password: "", cars: current.cars)
            await MainActor.run { self.currentUser = updatedUser }
        } catch {
            await MainActor.run { self.errorMessage = "Error updating profile." }
        }
    }

    // MARK: - Error messages

    private func firebaseErrorMessage(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case AuthErrorCode.wrongPassword.rawValue,
             AuthErrorCode.invalidCredential.rawValue:
            return "Incorrect email or password."
        case AuthErrorCode.userNotFound.rawValue:
            return "No account found with this email."
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "This email is already registered."
        case AuthErrorCode.weakPassword.rawValue:
            return "Password must be at least 6 characters."
        case AuthErrorCode.invalidEmail.rawValue:
            return "Please enter a valid email address."
        default:
            return "Something went wrong. Please try again."
        }
    }

    // MARK: - Dev helpers
    #if DEBUG
    func loginAsUser() {
        let mockCars = [
            Car(id: UUID(), plate: "ABC-123", UserID: UUID(), name: "Mi Camioneta"),
            Car(id: UUID(), plate: "XYZ-789", UserID: UUID(), name: "Carro de Ciudad")
        ]
        currentUser = User(id: UUID(), name: "Usuario Andes", email: "usuario@uniandes.edu.co", password: "", cars: mockCars)
        isLoggedIn = true
        isGerente = false
        currentUserEmail = "usuario@uniandes.edu.co"
    }

    func loginAsGerente() {
        currentUser = User(id: UUID(), name: "Gerente Andes", email: "gerente@uniandes.edu.co", password: "", cars: [])
        isLoggedIn = true
        isGerente = true
        currentUserEmail = "gerente@uniandes.edu.co"
    }
    #endif
}
