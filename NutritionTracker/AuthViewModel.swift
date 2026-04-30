import Foundation
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var isCreatingAccount = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        currentUser = Auth.auth().currentUser
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    var isSignedIn: Bool {
        currentUser != nil
    }

    var currentEmail: String {
        currentUser?.email ?? "Unknown account"
    }

    func submit() async {
        email = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !email.isEmpty else {
            errorMessage = "Enter an email address."
            return
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            if isCreatingAccount {
                _ = try await Auth.auth().createUser(withEmail: email, password: password)
            } else {
                _ = try await Auth.auth().signIn(withEmail: email, password: password)
            }

            password = ""
        } catch {
            errorMessage = isCreatingAccount
                ? Self.describe(error, context: .accountCreation)
                : Self.describe(error, context: .signIn)
        }

        isLoading = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            password = ""
            errorMessage = nil
        } catch {
            errorMessage = Self.describe(error, context: .general)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func sendPasswordReset(to emailAddress: String) async -> Bool {
        let resetEmail = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !resetEmail.isEmpty else {
            errorMessage = "Enter an email address."
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            try await Auth.auth().sendPasswordReset(withEmail: resetEmail)
            isLoading = false
            return true
        } catch {
            isLoading = false
            errorMessage = Self.describe(error, context: .passwordReset)
            return false
        }
    }

    func changePassword(currentPassword: String, newPassword: String, confirmPassword: String) async -> Bool {
        guard let user = currentUser, let email = user.email else {
            errorMessage = "No signed-in account was found."
            return false
        }

        guard !currentPassword.isEmpty else {
            errorMessage = "Enter your current password."
            return false
        }

        guard newPassword.count >= 6 else {
            errorMessage = "New password must be at least 6 characters."
            return false
        }

        guard newPassword == confirmPassword else {
            errorMessage = "New passwords do not match."
            return false
        }

        guard newPassword != currentPassword else {
            errorMessage = "Choose a new password that is different from your current password."
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
            try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: newPassword)
            isLoading = false
            return true
        } catch {
            isLoading = false
            errorMessage = Self.describe(error, context: .passwordChange)
            return false
        }
    }

    private enum ErrorContext {
        case general
        case signIn
        case accountCreation
        case passwordReset
        case passwordChange
    }

    private static func describe(_ error: Error, context: ErrorContext) -> String {
        let nsError = error as NSError

        if let authCode = AuthErrorCode(rawValue: nsError.code) {
            switch authCode {
            case .invalidEmail:
                return "That email address is not valid."
            case .wrongPassword:
                switch context {
                case .passwordChange:
                    return "Your current password is incorrect."
                case .passwordReset:
                    return "We couldn't send a password reset email right now. Please try again."
                default:
                    return "That password is incorrect."
                }
            case .invalidCredential:
                switch context {
                case .passwordChange:
                    return "Your current password is incorrect."
                case .passwordReset:
                    return "We couldn't send a password reset email right now. Please try again."
                default:
                    return "Your email or password is incorrect."
                }
            case .requiresRecentLogin:
                switch context {
                case .passwordChange:
                    return "Please sign out and sign back in before changing your password."
                case .passwordReset:
                    return "We couldn't send a password reset email right now. Please try again."
                default:
                    return "Please sign in again and try one more time."
                }
            case .userNotFound:
                return "No account was found for that email."
            case .emailAlreadyInUse:
                return "That email is already attached to an account."
            case .weakPassword:
                return context == .passwordChange
                    ? "Your new password is too weak. Choose a stronger password."
                    : "That password is too weak."
            case .networkError:
                return "We couldn't reach the network. Check your connection and try again."
            case .operationNotAllowed:
                return "Email/password sign-in is not enabled in Firebase yet."
            default:
                break
            }

            switch context {
            case .passwordReset:
                return "We couldn't send a password reset email right now. Please try again."
            case .passwordChange:
                return "We couldn't change your password right now. Please try again."
            case .signIn:
                return "We couldn't sign you in. Please check your details and try again."
            case .accountCreation:
                return "We couldn't create your account right now. Please try again."
            case .general:
                return "Something went wrong. Please try again."
            }
        }

        switch context {
        case .passwordReset:
            return "We couldn't send a password reset email right now. Please try again."
        case .passwordChange:
            return "We couldn't change your password right now. Please try again."
        case .signIn:
            return "We couldn't sign you in. Please try again."
        case .accountCreation:
            return "We couldn't create your account right now. Please try again."
        case .general:
            return "Something went wrong. Please try again."
        }
    }
}
