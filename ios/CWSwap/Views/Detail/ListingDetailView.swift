import SwiftUI

struct ListingDetailView: View {
    @State private var viewModel: ListingDetailViewModel
    @State private var showingContactSheet = false
    @State private var showingLoginAlert = false
    @State private var selectedImageIndex = 0
    @Environment(\.modelContext) private var modelContext

    private let authService = AuthenticationService()

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
                if listing.hasContactInfo {
                    contactSection
                }
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

                if listing.source == .ebay {
                    if let url = listing.sourceURL {
                        Link(destination: url) {
                            Label("View on eBay", systemImage: "safari")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                } else {
                    // Contact seller button
                    Button {
                        if authService.isLoggedIn {
                            showingContactSheet = true
                        } else {
                            showingLoginAlert = true
                        }
                    } label: {
                        Label("Contact Seller", systemImage: "message")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .sheet(isPresented: $showingContactSheet) {
                        NewConversationView(
                            recipient: listing.callsign,
                            title: "Re: \(listing.title)"
                        )
                    }
                    .alert("Login Required", isPresented: $showingLoginAlert) {
                        Button("OK") {}
                    } message: {
                        Text("Log in to your QRZ account in Settings to contact sellers.")
                    }
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
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contact Info")
                .font(.subheadline.weight(.semibold))

            if let email = listing.contactEmail, let url = URL(string: "mailto:\(email)") {
                Link(destination: url) {
                    Label(email, systemImage: "envelope")
                        .font(.body)
                }
            }

            if let phone = listing.contactPhone, let url = URL(string: "tel:\(phone.filter(\.isWholeNumber))") {
                Link(destination: url) {
                    Label(phone, systemImage: "phone")
                        .font(.body)
                }
            }

            if !listing.contactMethods.isEmpty {
                HStack(spacing: 6) {
                    Text("Accepts:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(listing.contactMethods, id: \.self) { method in
                        Text(method)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
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

            if listing.replies > 0 {
                LabeledContent("Replies") {
                    Text("\(listing.replies)")
                }
            }

            if listing.views > 0 {
                LabeledContent("Views") {
                    Text("\(listing.views)")
                }
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

