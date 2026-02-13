import SwiftUI

struct QRZLoginView: View {
    @State private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            if viewModel.isLoggedIn {
                loggedInSection
            } else {
                loginFormSection
            }

            if let error = viewModel.error {
                Section {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("QRZ Account")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.loginSucceeded) {
            if viewModel.loginSucceeded {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var loggedInSection: some View {
        Section {
            LabeledContent("Callsign") {
                Text(viewModel.storedUsername ?? "")
                    .font(.body.monospaced())
            }

            Button("Log Out", role: .destructive) {
                viewModel.logout()
            }
        }
    }

    @ViewBuilder
    private var loginFormSection: some View {
        Section("QRZ Forum Credentials") {
            TextField("Username / Callsign", text: $viewModel.username)
                .textContentType(.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)

            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
        }

        Section {
            Button {
                Task { await viewModel.login() }
            } label: {
                HStack {
                    Text("Log In")
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.username.isEmpty || viewModel.password.isEmpty || viewModel.isLoading)
        }

        Section {
            Text("Your QRZ credentials are stored securely in the iOS Keychain and are only used to access the QRZ Swapmeet forum.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
