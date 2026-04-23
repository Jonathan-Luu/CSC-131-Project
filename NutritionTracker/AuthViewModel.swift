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

    func submit() async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
            errorMessage = (error as NSError).localizedDescription
        }

        isLoading = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            password = ""
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}
