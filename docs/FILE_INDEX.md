# File Index

Complete file-to-purpose mapping for CW Swap. Update this when adding, removing, or renaming files.

## Backend — `backend/src/` (reference only, not used at runtime)

| File | Purpose |
|------|---------|
| `main.rs` | App entry point: config, DB pool init, optional QRZ login, optional scrape-on-start, axum server bind |
| `api/mod.rs` | REST API route handlers: listings query, single listing, categories, image proxy, health check |
| `db/mod.rs` | PostgreSQL connection, inline schema/migrations, query functions (query_listings, upsert_listing, get_categories) |
| `models/mod.rs` | Model re-exports |
| `models/listing.rs` | Listing, Source, Status, Category structs/enums |
| `models/price.rs` | Price struct (amount, currency, shipping, OBO) |
| `scraper/mod.rs` | Scraper module re-exports |
| `scraper/qrz.rs` | QRZ Forums scraper: login, listing page parsing, thread detail extraction, rate limiting |
| `scraper/price_extractor.rs` | Regex-based price extraction from listing text (includes unit tests) |

## iOS App — `ios/CWSwap/`

### Config

| File | Purpose |
|------|---------|
| `ios/project.yml` | XcodeGen spec: targets, deployment target, Swift version, build settings, SPM deps (SwiftSoup, KeychainAccess) |
| `CWSwapApp.swift` | App entry point, scene setup, SwiftData modelContainer |

### Models

| File | Purpose |
|------|---------|
| `Models/Listing.swift` | Main listing model (Codable, Sendable, Hashable) with direct URL construction |
| `Models/Price.swift` | Price with amount, currency, includesShipping, obo |
| `Models/ListingSource.swift` | Source enum (qrz, qth) |
| `Models/ListingStatus.swift` | Status enum (forSale, sold, canceled) |
| `Models/ListingCategory.swift` | 14 equipment categories with SF Symbols and display names |
| `Models/ListingsPage.swift` | Pagination wrapper (total, page, perPage, hasMore) |
| `Models/CategoryInfo.swift` | Category with listing count for category chips |
| `Models/PersistedListing.swift` | SwiftData @Model for offline caching + bookmarks, converts to/from Listing |

### Services

| File | Purpose |
|------|---------|
| `Services/PriceExtractor.swift` | Regex-based price extraction ported from Rust (amount, OBO, shipping detection) |
| `Services/KeychainManager.swift` | Wraps KeychainAccess for QRZ username/password storage |
| `Services/QRZScraper.swift` | QRZ Forums scraper (Sendable): login, listing page, thread detail, SwiftSoup parsing |
| `Services/QTHScraper.swift` | QTH.com scraper (Sendable): listing page, detail page, SwiftSoup parsing |
| `Services/ScrapingService.swift` | Coordinates both scrapers: fetch, filter, sort listings; static categories |
| `Services/AuthenticationService.swift` | QRZ login/logout, Keychain credential storage, reauthentication |
| `Services/ListingStore.swift` | SwiftData persistence: upsert, query, bookmark toggle |

### ViewModels

| File | Purpose |
|------|---------|
| `ViewModels/ListingsViewModel.swift` | Browse/search state: scraping + SwiftData cache, filters, pagination, sort |
| `ViewModels/ListingDetailViewModel.swift` | Single listing detail: refresh, bookmark toggle via ListingStore |
| `ViewModels/AuthViewModel.swift` | QRZ login/logout state: username, password, loading, error |

### Views

| File | Purpose |
|------|---------|
| `Views/ContentView.swift` | Tab navigation (Browse, Search, Messages, Saved, Settings) |
| `Views/Browse/BrowseView.swift` | Category chips + recent listings with infinite scroll |
| `Views/Browse/ListingCardView.swift` | Compact listing card: thumbnail, status badge, price, callsign, source badge |
| `Views/Search/SearchView.swift` | Searchable text field, filter chips, paginated results |
| `Views/Search/FilterSheetView.swift` | Filter sheet: category, source, price range, has-photos toggle |
| `Views/Detail/ListingDetailView.swift` | Full listing detail: image carousel, price, callsign, description, bookmark, share |
| `Views/Saved/SavedView.swift` | Bookmarked listings from SwiftData with swipe-to-remove |
| `Views/Settings/SettingsView.swift` | Settings form with QRZ account link and app info |
| `Views/Settings/QRZLoginView.swift` | QRZ login form with Keychain-backed credential storage |

## Reference Files

| File | Purpose |
|------|---------|
| `ham-classifieds-design.md` | Original architecture design document (Options A/B/C, schema design) |
| `hamswap-prototype.jsx` | React prototype (reference only, not active code) |
| `qrz_sources/items.php` | Sample QRZ listing page HTML |
| `qrz_sources/item_for_sale.php` | Sample QRZ thread detail HTML |
| `qrz_sources/conversations.php` | Sample QRZ conversations list HTML |
| `qrz_sources/conversation.php` | Sample QRZ single conversation HTML |
| `qrz_sources/contact.php` | Sample QRZ contact page HTML |
