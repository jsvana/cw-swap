import SwiftUI

struct ListingCardView: View {
    let listing: Listing

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack(alignment: .topLeading) {
                if let url = listing.firstPhotoUrl {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            placeholderImage
                        default:
                            ProgressView()
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    placeholderImage
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Lot number badge for auctions
                if let auctionMeta = listing.auctionMeta, !auctionMeta.lotNumber.isEmpty {
                    Text("Lot \(auctionMeta.lotNumber)")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(3)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Status badge + title
                HStack(spacing: 6) {
                    if listing.status == .sold && listing.auctionMeta == nil {
                        Text("SOLD")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    Text(listing.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                }

                // Price / Bid info
                if let auctionMeta = listing.auctionMeta {
                    auctionPriceRow(auctionMeta)
                } else if let price = listing.formattedPrice {
                    Text(price)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }

                // Metadata row
                HStack(spacing: 8) {
                    if listing.isAuction {
                        // Auctioneer name instead of callsign
                        Text(listing.callsign)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        // Callsign
                        Text(listing.callsign)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    // Source badge
                    Text(listing.source.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(sourceBadgeColor)
                        .clipShape(Capsule())

                    Spacer()

                    // Time remaining for auctions, time ago for classifieds
                    if let auctionMeta = listing.auctionMeta {
                        timeRemainingPill(auctionMeta)
                    } else {
                        Text(listing.timeAgo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Auction-specific views

    @ViewBuilder
    private func auctionPriceRow(_ meta: AuctionMeta) -> some View {
        HStack(spacing: 4) {
            if let bid = meta.formattedBid {
                Text(bid)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text("(\(meta.bidCount) \(meta.bidCount == 1 ? "bid" : "bids"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No bids")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let minBid = meta.formattedBid {
                    Text("Min: \(minBid)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func timeRemainingPill(_ meta: AuctionMeta) -> some View {
        Text(meta.computedTimeLeftDisplay)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(timeLeftBackground(meta.timeLeftColor))
            .foregroundStyle(timeLeftForeground(meta.timeLeftColor))
            .clipShape(Capsule())
    }

    private func timeLeftBackground(_ color: AuctionMeta.TimeLeftColor) -> Color {
        switch color {
        case .green: Color.green.opacity(0.15)
        case .amber: Color.orange.opacity(0.15)
        case .red: Color.red.opacity(0.15)
        case .gray: Color(.systemGray5)
        }
    }

    private func timeLeftForeground(_ color: AuctionMeta.TimeLeftColor) -> Color {
        switch color {
        case .green: .green
        case .amber: .orange
        case .red: .red
        case .gray: .secondary
        }
    }

    private var sourceBadgeColor: Color {
        switch listing.source {
        case .hibid: Color.purple.opacity(0.2)
        default: Color.blue.opacity(0.2)
        }
    }

    private var placeholderImage: some View {
        Image(systemName: "photo")
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray5))
    }
}
