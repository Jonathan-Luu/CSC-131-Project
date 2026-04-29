import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var successMessage: String?

    var body: some View {
        Form {
            Section("Account") {
                HStack {
                    Text("Signed in as")
                    Spacer()
                    Text(authViewModel.currentEmail)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Change Password") {
                SecureField("Current Password", text: $currentPassword)
                    .textContentType(.password)

                SecureField("New Password", text: $newPassword)
                    .textContentType(.newPassword)

                SecureField("Confirm New Password", text: $confirmPassword)
                    .textContentType(.newPassword)

                Button {
                    Task {
                        let didChange = await authViewModel.changePassword(
                            currentPassword: currentPassword,
                            newPassword: newPassword,
                            confirmPassword: confirmPassword
                        )

                        if didChange {
                            currentPassword = ""
                            newPassword = ""
                            confirmPassword = ""
                            successMessage = "Your password has been changed successfully."
                        } else {
                            successMessage = nil
                        }
                    }
                } label: {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView()
                        }
                        Text("Update Password")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(authViewModel.isLoading)

                if let successMessage {
                    Text(successMessage)
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                }
            }
        }
        .navigationTitle("Profile")
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: currentPassword) { _ in clearMessages() }
        .onChange(of: newPassword) { _ in clearMessages() }
        .onChange(of: confirmPassword) { _ in clearMessages() }
    }

    private func clearMessages() {
        successMessage = nil
        authViewModel.clearError()
    }
}
