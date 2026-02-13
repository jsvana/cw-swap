import SwiftUI

struct ConversationDetailView: View {
    @State private var viewModel: ConversationDetailViewModel

    init(conversation: Conversation) {
        _viewModel = State(initialValue: ConversationDetailViewModel(conversation: conversation))
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesList
            replyBar
        }
        .navigationTitle(viewModel.conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadMessages()
        }
    }

    @ViewBuilder
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.isLoading && viewModel.messages.isEmpty {
                    ProgressView("Loading messages...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let error = viewModel.error, viewModel.messages.isEmpty {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.loadMessages() }
                        }
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isCurrentUser: message.author.lowercased() == viewModel.currentUsername?.lowercased()
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
            }
            .onChange(of: viewModel.messages.count) {
                if let lastId = viewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var replyBar: some View {
        Divider()
        HStack(spacing: 8) {
            TextField("Reply...", text: $viewModel.replyText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)

            Button {
                Task { await viewModel.sendReply() }
            } label: {
                if viewModel.isSending {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
            }
            .disabled(viewModel.replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isCurrentUser { Spacer(minLength: 40) }

            if !isCurrentUser {
                avatar
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isCurrentUser {
                    Text(message.author)
                        .font(.caption.monospaced().weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(message.body)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color.accentColor : Color(.systemGray5))
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(message.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if isCurrentUser {
                avatar
            }

            if !isCurrentUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        AsyncImage(url: message.avatarURL.flatMap { URL(string: $0) }) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Image(systemName: "person.circle.fill")
                .foregroundStyle(.secondary)
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }
}
