import SwiftUI

struct ListingCardView: View {
    let listing: Listing

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
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

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Status badge + title
                HStack(spacing: 6) {
                    if listing.status == .sold {
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

                // Price
                if let price = listing.formattedPrice {
                    Text(price)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }

                // Metadata row
                HStack(spacing: 8) {
                    // Callsign
                    Text(listing.callsign)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    // Source badge
                    Text(listing.source.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())

                    Spacer()

                    // Time ago
                    Text(listing.timeAgo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var placeholderImage: some View {
        Image(systemName: "photo")
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray5))
    }
}
