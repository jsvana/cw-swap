import SwiftUI
import SwiftData

struct SavedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<PersistedListing> { $0.isBookmarked == true },
           sort: \PersistedListing.dateScraped, order: .reverse)
    private var bookmarks: [PersistedListing]

    var body: some View {
        Group {
            if bookmarks.isEmpty {
                ContentUnavailableView(
                    "No Saved Listings",
                    systemImage: "bookmark",
                    description: Text("Tap the bookmark icon on a listing to save it here.")
                )
            } else {
                List {
                    ForEach(bookmarks, id: \.id) { persisted in
                        let listing = persisted.toListing()
                        NavigationLink(value: listing) {
                            ListingCardView(listing: listing)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .listRowSeparator(.hidden)
                    }
                    .onDelete(perform: removeBookmarks)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Saved")
        .navigationDestination(for: Listing.self) { listing in
            ListingDetailView(listing: listing)
        }
    }

    private func removeBookmarks(at offsets: IndexSet) {
        for index in offsets {
            bookmarks[index].isBookmarked = false
        }
        try? modelContext.save()
    }
}
