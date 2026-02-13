import SwiftUI

struct ConversationsView: View {
    @State private var viewModel = ConversationsViewModel()
    @State private var showingNewConversation = false

    var body: some View {
        Group {
            if viewModel.isLoggedIn {
                conversationsList
            } else {
                ContentUnavailableView(
                    "Messages",
                    systemImage: "message",
                    description: Text("Log in to your QRZ account to message sellers.")
                )
            }
        }
        .navigationTitle("Messages")
        .toolbar {
            if viewModel.isLoggedIn {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewConversation = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewConversation) {
            NewConversationView()
        }
    }

    @ViewBuilder
    private var conversationsList: some View {
        Group {
            if viewModel.isLoading && viewModel.conversations.isEmpty {
                ProgressView("Loading conversations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.conversations.isEmpty {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.loadConversations() }
                    }
                }
            } else if viewModel.conversations.isEmpty {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "message",
                    description: Text("Start a conversation by contacting a seller.")
                )
            } else {
                List(viewModel.conversations) { conversation in
                    NavigationLink(value: conversation) {
                        ConversationRowView(conversation: conversation)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationDestination(for: Conversation.self) { conversation in
            ConversationDetailView(conversation: conversation)
        }
        .refreshable {
            await viewModel.loadConversations()
        }
        .task {
            if viewModel.conversations.isEmpty {
                await viewModel.loadConversations()
            }
        }
    }
}

struct ConversationRowView: View {
    let conversation: Conversation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            AsyncImage(url: avatarURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(conversation.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                // Participants
                Text(conversation.participants.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Last reply info
                HStack(spacing: 4) {
                    Text(conversation.lastPoster)
                        .font(.caption.monospaced())
                    Text(conversation.timeAgo)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Reply count badge
            if conversation.replyCount > 0 {
                Text("\(conversation.replyCount)")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var avatarURL: URL? {
        conversation.avatarURL.flatMap { URL(string: $0) }
    }
}
