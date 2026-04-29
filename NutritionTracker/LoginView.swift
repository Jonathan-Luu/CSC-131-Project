import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)

                        Text("Nutrition Tracker")
                            .font(.largeTitle.bold())

                        Text(authViewModel.isCreatingAccount ? "Create an account to save your nutrition data." : "Sign in to continue to your tracker.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 16) {
                        TextField("Email", text: $authViewModel.email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        SecureField("Password", text: $authViewModel.password)
                            .textContentType(authViewModel.isCreatingAccount ? .newPassword : .password)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task {
                            await authViewModel.submit()
                        }
                    } label: {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(authViewModel.isCreatingAccount ? "Create Account" : "Sign In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(authViewModel.isLoading ? Color.gray : Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(authViewModel.isLoading)

                    Button(authViewModel.isCreatingAccount ? "Already have an account? Sign In" : "Need an account? Create One") {
                        authViewModel.isCreatingAccount.toggle()
                        authViewModel.errorMessage = nil
                    }
                    .font(.footnote.weight(.medium))

                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarHidden(true)
        }
    }
}
