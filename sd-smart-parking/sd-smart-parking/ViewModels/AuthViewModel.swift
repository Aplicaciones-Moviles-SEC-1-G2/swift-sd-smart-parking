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

    /// True when a Microsoft session is cached in Firebase but the user has
    /// NOT yet explicitly tapped the Microsoft button in this app launch.
    /// LoginView observes this to swap the button into a "Continue as <email>"
    /// confirmation, instead of letting the auth-state listener auto-route
    /// straight into the app.
    @Published var pendingMicrosoftAutoLogin: Bool = false

    /// Gate consumed by the auth-state listener: only after the user has
    /// explicitly chosen to proceed with the cached Microsoft session (or
    /// completed a fresh sign-in) do we let the listener route into the app.
    /// Resets each app launch because it lives in instance state.
    private var allowMicrosoftAutoEntry: Bool = false

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
    private let keychain: KeychainStoring
    private var authStateListener: AuthStateDidChangeListenerHandle?

    init(
        microsoftOAuth: MicrosoftOAuthProviding = FirebaseMicrosoftOAuth(),
        keychain: KeychainStoring = KeychainHelper.live
    ) {
        self.microsoftOAuth = microsoftOAuth
        self.keychain = keychain
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            if let firebaseUser = firebaseUser {
                // Gate cached Microsoft sessions: even though Firebase has a
                // valid persisted credential, we keep the user on LoginView
                // until they explicitly tap the Microsoft button. This gives
                // them the option to switch to another provider on every
                // launch instead of being silently auto-routed into the app.
                let isMicrosoftSession = firebaseUser.providerData
                    .contains { $0.providerID == "microsoft.com" }
                if isMicrosoftSession && !self.allowMicrosoftAutoEntry {
                    DispatchQueue.main.async {
                        self.pendingMicrosoftAutoLogin = true
                        self.currentUserEmail = firebaseUser.email
                        self.isLoggedIn = false
                        self.isLoading = false
                    }
                    return
                }
                self.currentUserEmail = firebaseUser.email
                Task { await self.fetchUserData(uid: firebaseUser.uid) }
            } else {
                DispatchQueue.main.async {
                    self.isLoggedIn = false
                    self.isGerente = false
                    self.currentUser = nil
                    self.currentUserEmail = nil
                    self.pendingMicrosoftAutoLogin = false
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
                // ... lógica de creación de usuario nuevo se mantiene igual
                return
            }
            
            guard let data = doc.data() else { return }
            
            let name = data["name"] as? String ?? ""
            let email = data["email"] as? String ?? ""
            let role = data["role"] as? String ?? "driver"
            
            // --- TRANSFORMACIÓN A ARRAYMAP ---
            let carsData = data["cars"] as? [[String: Any]] ?? []
            var carsMap = ArrayMap<String, Car>() // Inicializamos el mapa vacío
            
            for carData in carsData {
                guard let plate = carData["plate"] as? String,
                      let carName = carData["name"] as? String else { continue }
                
                let car = Car(
                    id: UUID(),
                    plate: plate,
                    UserID: uid,
                    name: carName
                )
                // Insertamos en el mapa usando la placa normalizada como clave
                carsMap.put(car, for: car.normalizedPlate)
            }
            
            // Preferencias personalizadas (puede no existir en el doc)
            let preferences = UserPreferences(firestore: data["preferences"] as? [String: Any])

            // Creamos al User pasando el ArrayMap
            let user = User(id: UUID(uuidString: uid) ?? UUID(), name: name, email: email, password: "", cars: carsMap, preferences: preferences)
            
            await MainActor.run {
                self.currentUser = user
                self.isGerente = role == "manager"
                self.isLoggedIn = true
                self.isLoading = false
                if self.biometricsEnabled {
                    self.requiresBiometricUnlock = true
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error loading user data."
                self.isLoading = false}
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
            // The user is explicitly choosing Microsoft now — release the gate
            // so the auth-state listener routes the resulting session into the
            // app instead of bouncing back to "pending Microsoft auto login".
            allowMicrosoftAutoEntry = true
            pendingMicrosoftAutoLogin = false
        }

        do {
            try await microsoftOAuth.signIn()

            // Persist a "remember last Microsoft user" hint in Keychain so
            // we can show a "Continue as <email>" caption on next launch.
            // Best-effort: failures don't surface to the user.
            if let user = Auth.auth().currentUser, let email = user.email {
                MicrosoftKeychain.saveCredentials(uid: user.uid, email: email)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Microsoft Sign-In was cancelled or failed."
                self.isLoading = false
                // OAuth failed — re-arm the gate so a still-cached Firebase
                // session won't sneak the user in on the next listener fire.
                self.allowMicrosoftAutoEntry = false
            }
        }
    }

    /// Acknowledges a cached Microsoft session that was gated on app launch.
    /// Reuses the existing Firebase credential — no OAuth re-prompt — and
    /// runs the normal `fetchUserData` flow that sets `isLoggedIn = true`.
    func continueWithCachedMicrosoftSession() async {
        guard let firebaseUser = Auth.auth().currentUser else {
            await MainActor.run { self.pendingMicrosoftAutoLogin = false }
            return
        }
        await MainActor.run {
            self.allowMicrosoftAutoEntry = true
            self.pendingMicrosoftAutoLogin = false
            self.isLoading = true
            self.errorMessage = nil
            self.currentUserEmail = firebaseUser.email
        }
        await fetchUserData(uid: firebaseUser.uid)
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
    func signOut(userRepo: UserRepository) { // Pasamos el repo como parámetro
        let ctx = LAContext()
        var err: NSError?
        let hasBiometrics = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
        
        if hasBiometrics && biometricsEnabled {
            // --- SOFT LOGOUT ---
            // Mantenemos la sesión de Firebase y el JSON local
            // para que la entrada con Face ID sea instantánea.
            _lastGerente = isGerente
            isLoggedIn = false
            requiresBiometricUnlock = true
            errorMessage = nil
        } else {
            // --- HARD LOGOUT ---
            // 1. Limpiamos Firebase y Google
            try? Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()

            // 2. Limpiamos el caché físico y la memoria del Repo
            userRepo.clearUserData()

            // 3. Limpiamos las credenciales de Microsoft del Keychain — la
            //    sesión Microsoft no debe sobrevivir a un logout explícito.
            MicrosoftKeychain.clearCredentials(store: keychain)

            // 4. Limpiamos el estado del AuthViewModel
            isLoggedIn = false
            isGerente = false
            currentUser = nil
            currentUserEmail = nil
            requiresBiometricUnlock = false
            errorMessage = nil
            pendingMicrosoftAutoLogin = false
            allowMicrosoftAutoEntry = false
        }
    }
    // Stores the last role so biometric re-login can restore it in dev mode
    private var _lastGerente: Bool = false

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
        var mockCarsMap = ArrayMap<String, Car>()
        
        let car1 = Car(id: UUID(), plate: "ABC-123", UserID: "PREV1", name: "Mi Camioneta")
        let car2 = Car(id: UUID(), plate: "XYZ-789", UserID: "PREV2", name: "Carro de Ciudad")
        
        // Importante: Usar put para que se mantengan ordenados y con sus llaves
        mockCarsMap.put(car1, for: car1.normalizedPlate)
        mockCarsMap.put(car2, for: car2.normalizedPlate)
        
        currentUser = User(id: UUID(), name: "Usuario Andes", email: "usuario@uniandes.edu.co", password: "", cars: mockCarsMap, preferences: nil)
        isLoggedIn = true
        isGerente = false
        currentUserEmail = "usuario@uniandes.edu.co"
    }
    
    func loginAsGerente() {
        // Para el gerente pasamos un ArrayMap vacío
        currentUser = User(id: UUID(), name: "Gerente Andes", email: "gerente@uniandes.edu.co", password: "", cars: ArrayMap<String, Car>(), preferences: nil)
        isLoggedIn = true
        isGerente = true
        currentUserEmail = "gerente@uniandes.edu.co"
    }
#endif
}
