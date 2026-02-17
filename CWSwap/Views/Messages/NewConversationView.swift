import SwiftUI

struct NewConversationView: View {
    @State private var viewModel: NewConversationViewModel
    @Environment(\.dismiss) private var dismiss

    init(recipient: String = "", title: String = "", listingUrl: String? = nil) {
        _viewModel = State(initialValue: NewConversationViewModel(recipient: recipient, title: title, listingUrl: listingUrl))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("To") {
                    TextField("Callsign", text: $viewModel.recipient)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                }

                Section("Subject") {
                    TextField("Conversation Title", text: $viewModel.title)
                }

                Section("Message") {
                    TextEditor(text: $viewModel.messageBody)
                        .frame(minHeight: 120)
                }

                if let error = viewModel.error {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task {
                            await viewModel.send()
                            if viewModel.didSend {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canSend)
                }
            }
            .overlay {
                if viewModel.isSending {
                    ProgressView("Sending...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var canSend: Bool {
        !viewModel.recipient.isEmpty
            && !viewModel.title.isEmpty
            && !viewModel.messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isSending
    }
}
