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
                if let auctionMeta = listing.auctionMeta {
                    auctionInfoSection(auctionMeta)
                }
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
            let store = ListingStore(modelContext: modelContext)
            try? store.markAsSeen(listingIds: [listing.id])
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
            if listing.isAuction, let auctionMeta = listing.auctionMeta {
                // Auction status badge
                Text(auctionMeta.auctionStatus.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(auctionStatusColor(auctionMeta.auctionStatus))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else if listing.status != .forSale {
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

            // Price / Bid
            if let auctionMeta = listing.auctionMeta {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(auctionMeta.formattedBid ?? "No bids yet")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                        Text("(\(auctionMeta.bidCount) \(auctionMeta.bidCount == 1 ? "bid" : "bids"))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    // Time remaining
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(auctionMeta.computedTimeLeftDisplay)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(timeLeftTextColor(auctionMeta.timeLeftColor))
                }
            } else if let price = listing.formattedPrice {
                Text(price)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            // Seller / Auctioneer info + action button
            HStack(spacing: 8) {
                if !listing.isAuction, let url = listing.avatarURL {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                }

                if listing.isAuction {
                    Text(listing.callsign)
                        .font(.body.weight(.medium))
                } else {
                    Text(listing.callsign)
                        .font(.body.monospaced().weight(.medium))
                }

                Spacer()

                if listing.isAuction {
                    if let url = listing.auctionMeta?.bidURL {
                        Link(destination: url) {
                            Label("Bid on HiBid", systemImage: "gavel")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                } else if listing.source == .ebay {
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

    // MARK: - Auction Info Section

    @ViewBuilder
    private func auctionInfoSection(_ meta: AuctionMeta) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Auction Details")
                .font(.subheadline.weight(.semibold))

            // Bid info grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 8) {
                if let highBid = meta.formattedBid {
                    auctionInfoCell(label: "High Bid", value: highBid)
                }

                if let minBid = meta.minBid, minBid > 0 {
                    let formatter = NumberFormatter()
                    let _ = formatter.numberStyle = .currency
                    let _ = formatter.currencyCode = "USD"
                    auctionInfoCell(label: "Min Next Bid", value: formatter.string(from: NSNumber(value: minBid)) ?? "$\(Int(minBid))")
                }

                auctionInfoCell(label: "Bids", value: "\(meta.bidCount)")

                if let buyNow = meta.formattedBuyNow {
                    auctionInfoCell(label: "Buy Now", value: buyNow)
                }
            }

            // Reserve status
            if let reserveMet = meta.reserveMet {
                HStack(spacing: 4) {
                    Image(systemName: reserveMet ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(reserveMet ? .green : .orange)
                    Text(reserveMet ? "Reserve met" : "Reserve not met")
                        .font(.subheadline)
                        .foregroundStyle(reserveMet ? .green : .orange)
                }
            }

            // Shipping
            if meta.shippingOffered {
                HStack(spacing: 4) {
                    Image(systemName: "shippingbox")
                    Text("Shipping offered")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }

            // Auctioneer
            LabeledContent("Auctioneer") {
                Text(meta.auctioneerName)
            }
            .font(.subheadline)

            if !meta.lotNumber.isEmpty {
                LabeledContent("Lot") {
                    Text(meta.lotNumber)
                }
                .font(.subheadline)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func auctionInfoCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func auctionStatusColor(_ status: AuctionStatus) -> Color {
        switch status {
        case .open: .green
        case .closing, .live: .orange
        case .closed: .red
        case .notYetLive: .gray
        }
    }

    private func timeLeftTextColor(_ color: AuctionMeta.TimeLeftColor) -> Color {
        switch color {
        case .green: .green
        case .amber: .orange
        case .red: .red
        case .gray: .secondary
        }
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
