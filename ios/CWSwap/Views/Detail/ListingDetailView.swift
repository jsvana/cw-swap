import SwiftUI

struct ListingDetailView: View {
    @State private var viewModel: ListingDetailViewModel
    @State private var showingContactSheet = false
    @State private var selectedImageIndex = 0
    @Environment(\.modelContext) private var modelContext

    init(listing: Listing) {
        _viewModel = State(initialValue: ListingDetailViewModel(listing: listing))
    }

    private var listing: Listing { viewModel.listing }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                imageSection
                headerSection
                descriptionSection
                metadataSection
            }
        }
        .navigationTitle(listing.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ShareLink(item: listing.sourceUrl) {
                    Image(systemName: "square.and.arrow.up")
                }

                Button {
                    viewModel.toggleBookmark()
                } label: {
                    Image(systemName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            viewModel.setModelContext(modelContext)
        }
    }

    @ViewBuilder
    private var imageSection: some View {
        if listing.hasPhotos {
            TabView(selection: $selectedImageIndex) {
                ForEach(Array(listing.photoUrls.enumerated()), id: \.offset) { index, _ in
                    if let url = listing.photoURL(at: index) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            case .failure:
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            default:
                                ProgressView()
                            }
                        }
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page)
            .frame(height: 300)
            .background(Color(.systemGray5))
        } else {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color(.systemGray5))
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status
            if listing.status != .forSale {
                Text(listing.status.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(listing.status == .sold ? Color.red : Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            // Title
            Text(listing.title)
                .font(.title2.bold())

            // Price
            if let price = listing.formattedPrice {
                Text(price)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            // Seller info
            HStack(spacing: 8) {
                if let url = listing.avatarURL {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                }

                Text(listing.callsign)
                    .font(.body.monospaced().weight(.medium))

                Spacer()

                // Contact seller button
                Button {
                    showingContactSheet = true
                } label: {
                    Label("Contact Seller", systemImage: "message")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .sheet(isPresented: $showingContactSheet) {
                    ContactSellerSheet(listing: listing)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.subheadline.weight(.semibold))

            Text(listing.description)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            LabeledContent("Source") {
                Text(listing.source.displayName)
            }

            LabeledContent("Posted") {
                Text(listing.datePosted, style: .date)
            }

            if let modified = listing.dateModified {
                LabeledContent("Modified") {
                    Text(modified, style: .date)
                }
            }

            LabeledContent("Replies") {
                Text("\(listing.replies)")
            }

            LabeledContent("Views") {
                Text("\(listing.views)")
            }

            if let url = listing.sourceURL {
                Link(destination: url) {
                    Label("View on \(listing.source.displayName)", systemImage: "safari")
                }
                .padding(.top, 4)
            }
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.bottom, 32)
    }
}

struct ContactSellerSheet: View {
    let listing: Listing
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("To") {
                    Text(listing.callsign)
                        .font(.body.monospaced())
                }
                Section("Subject") {
                    Text(listing.title)
                }
                Section("Message") {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Contact Seller")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        // TODO: Send via API
                        dismiss()
                    }
                    .disabled(message.isEmpty)
                }
            }
        }
    }
}
