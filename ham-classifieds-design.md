# HamSwap — Ham Radio Classifieds Aggregator

## Overview

A native iOS app that aggregates ham radio classified ads from multiple sources (swap.qth.com, QRZ Swapmeet) into a unified, searchable, filterable interface with a modern UI.

---

## Architecture

### Option A: SwiftUI + Rust Backend (Recommended)

```
┌─────────────────────────────────────┐
│         SwiftUI iOS App             │
│  ┌───────────┐  ┌────────────────┐  │
│  │  Views     │  │  ViewModels    │  │
│  │  (SwiftUI) │  │  (Observable)  │  │
│  └─────┬─────┘  └───────┬────────┘  │
│        └────────┬────────┘           │
│           ┌─────▼──────┐            │
│           │  Data Layer │            │
│           └─────┬──────┘            │
└─────────────────┼───────────────────┘
                  │ HTTPS
    ┌─────────────▼──────────────┐
    │   Rust Backend (Cloud Run) │
    │  ┌──────────────────────┐  │
    │  │  Scraper Engine      │  │
    │  │  (reqwest + scraper) │  │
    │  ├──────────────────────┤  │
    │  │  Normalizer / Parser │  │
    │  ├──────────────────────┤  │
    │  │  REST API (axum)     │  │
    │  ├──────────────────────┤  │
    │  │  SQLite / PostgreSQL │  │
    │  └──────────────────────┘  │
    └────────────────────────────┘
```

**Why this approach:**
- Rust scraper handles HTML parsing fast and reliably (you're already fluent)
- Backend normalizes data from multiple sources into one schema
- iOS app stays thin — just UI + networking
- Cloud Run on GCP (your existing infra) with scheduled scrape jobs
- Could reuse the backend for a web frontend later

### Option B: Tauri 2 Mobile

Since you've built Tauri apps before, Tauri 2 now supports iOS/Android. The scraping could happen on-device or via a lightweight backend. Tradeoff: Tauri mobile is still maturing, and App Store distribution is less battle-tested.

### Option C: Pure SwiftUI + On-Device Scraping

Simplest to start — the app scrapes directly. Downside: slower, battery drain, and harder to add QRZ auth flow.

**Recommendation: Option A** — gives you the cleanest separation, lets you iterate the backend independently, and you can add new sources without app updates.

---

## Data Model

### Unified Listing Schema

```rust
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Listing {
    pub id: String,                    // "{source}:{source_id}" e.g. "qth:1758114"
    pub source: Source,
    pub source_url: String,
    pub source_id: String,

    // Content
    pub title: String,                 // Extracted/generated from description
    pub description: String,
    pub category: Category,
    pub listing_type: ListingType,     // ForSale, Wanted, Trade

    // Seller
    pub callsign: Option<String>,
    pub location: Option<String>,      // Parsed from description when possible

    // Pricing
    pub price: Option<Price>,

    // Media
    pub photo_urls: Vec<String>,

    // Metadata
    pub date_posted: DateTime<Utc>,
    pub date_modified: Option<DateTime<Utc>>,
    pub date_scraped: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum Source {
    QthSwap,
    QrzSwapmeet,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum Category {
    HfRadios,
    VhfUhfRadios,
    HfAmplifiers,
    VhfUhfAmplifiers,
    HfAntennas,
    VhfUhfAntennas,
    Towers,
    Rotators,
    Keys,           // CW keys, paddles, keyers
    TestEquipment,
    Computers,
    AntiqueRadios,
    Accessories,
    Miscellaneous,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum ListingType {
    ForSale,
    Wanted,
    Trade,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Price {
    pub amount: f64,
    pub currency: String,            // Usually "USD"
    pub includes_shipping: bool,
    pub obo: bool,                   // "Or Best Offer"
}
```

### QTH.com Category Mapping

| QTH Slug     | URL                    | Mapped Category     |
|-------------|------------------------|---------------------|
| radiohf     | c_radiohf.php          | HfRadios            |
| radiovhf    | c_radiovhf.php         | VhfUhfRadios        |
| amphf       | c_amphf.php            | HfAmplifiers        |
| ampvhf      | c_ampvhf.php           | VhfUhfAmplifiers    |
| anthf       | c_anthf.php            | HfAntennas          |
| antvhf      | c_antvhf.php           | VhfUhfAntennas      |
| towers      | c_towers.php           | Towers              |
| rotators    | c_rotators.php         | Rotators            |
| keys        | c_keys.php             | Keys                |
| testequip   | c_testequip.php        | TestEquipment       |
| computers   | c_computers.php        | Computers           |
| radioanq    | c_radioanq.php         | AntiqueRadios       |
| acchf       | c_acchf.php            | Accessories         |
| misc        | c_misc.php             | Miscellaneous       |

### QTH.com Scraping Strategy

**Listing page pattern:**
```
https://swap.qth.com/c_{category}.php?page={n}
```

**Listing detail (individual ad):**
```
https://swap.qth.com/view_ad.php?counter={listing_id}
```

**Search:**
```
https://swap.qth.com/search-results.php?keywords={q}&fieldtosearch={field}&startnum={offset}
```

**Parsing approach** (using `scraper` crate):
1. Each listing block follows a consistent pattern:
   - `Listing #{id}` — regex extract the numeric ID
   - `Submitted on {date}` — parse date
   - `by Callsign {call}` — extract callsign
   - `Modified on {date}` — optional modified date
   - Description text follows
   - "Click Here to View Picture" indicates photo availability
2. Photo URLs: follow the picture link pattern per listing ID
3. Price extraction: regex for `$\d+[\d,.]*` patterns in description
4. Listing type detection: keyword scan for "wanted", "wtb", "looking for", "trade"

**Scrape schedule:**
- Full scrape: every 4 hours (the site updates slowly)
- Incremental: check first page of each category every 30 min for new listings
- Rate limit: 1 request per second with polite User-Agent

---

## API Design

### Endpoints

```
GET  /api/v1/listings
     ?category={category}
     &type={for_sale|wanted|trade}
     &source={qth|qrz}
     &q={search_text}
     &callsign={callsign}
     &price_min={min}
     &price_max={max}
     &has_photo={true|false}
     &sort={newest|oldest|price_asc|price_desc}
     &page={n}
     &per_page={n}

GET  /api/v1/listings/{id}

GET  /api/v1/categories
     → returns categories with listing counts

GET  /api/v1/saved-searches
POST /api/v1/saved-searches
DELETE /api/v1/saved-searches/{id}

POST /api/v1/devices
     → register for push notifications on saved searches
```

### Response Format

```json
{
  "listings": [...],
  "total": 1842,
  "page": 1,
  "per_page": 20,
  "has_more": true
}
```

---

## iOS App Design

### Navigation Structure

```
TabBar
├── Browse (default)
│   ├── Category grid / list
│   └── Listing feed (filtered by category)
│       └── Listing detail
├── Search
│   ├── Full-text search bar
│   ├── Filter sheet (category, price, type, source, has photo)
│   └── Results feed
│       └── Listing detail
├── Saved
│   ├── Saved searches (with notification badges)
│   ├── Bookmarked listings
│   └── Recently viewed
└── Settings
    ├── Source management (QTH, QRZ login)
    ├── Notification preferences
    └── About
```

### Key Screens

#### 1. Browse / Home
- Top: horizontal scrollable category chips (with icons)
- "New Today" section with recent listings
- Category cards with thumbnail + count
- Pull-to-refresh

#### 2. Listing Feed
- Card-based layout: photo thumbnail (if available), title, price badge, callsign, time ago
- Swipe actions: bookmark, share
- Sticky filter bar at top

#### 3. Listing Detail
- Hero image (if photo available) with zoom
- Title, price (prominent), callsign with QRZ lookup link
- Full description
- Metadata: source, date posted, category
- Action buttons: Contact Seller, Bookmark, Share
- "More from this seller" section

#### 4. Search + Filters
- Instant search with debounced API calls
- Filter sheet (half-modal):
  - Category (multi-select chips)
  - Listing type: For Sale / Wanted / Trade
  - Price range slider
  - Source: QTH / QRZ / All
  - Has photo toggle
  - Sort by: Newest, Price ↑, Price ↓
- Active filters shown as dismissible chips below search bar

#### 5. Saved Searches
- List of saved filter combinations
- Each shows: filter summary, new listing count since last viewed
- Push notification support for new matches

### UI Direction

**Aesthetic: Clean utilitarian with ham radio character**

- Dark mode primary (easy on the eyes in the shack)
- Accent color: amber/gold (evoking warm tube glow)
- Monospace elements for callsigns and listing IDs
- Category icons using SF Symbols (antenna, radio, waveform, etc.)
- Card-based listing items with subtle depth
- Typography: system fonts but with monospace callsign treatment

---

## Tech Stack Summary

| Layer         | Technology                              |
|--------------|------------------------------------------|
| iOS App      | SwiftUI, Swift Concurrency, SwiftData   |
| Networking   | URLSession + async/await                 |
| Backend      | Rust (axum + tokio)                      |
| Scraper      | reqwest + scraper crate                  |
| Database     | PostgreSQL (or SQLite for simplicity)    |
| Hosting      | Google Cloud Run + Cloud Scheduler       |
| Push Notifs  | APNs via Cloud Run                       |
| Image Cache  | Kingfisher (iOS) or Nuke                 |

---

## Development Phases

### Phase 1: Backend + Scraper (1-2 weeks)
- [ ] QTH.com scraper with all categories
- [ ] Listing parser and normalizer
- [ ] Price extraction heuristics
- [ ] PostgreSQL schema + migrations
- [ ] REST API with basic listing/search endpoints
- [ ] Cloud Run deployment + scheduled scraping

### Phase 2: iOS MVP (2-3 weeks)
- [ ] Browse screen with category grid
- [ ] Listing feed with infinite scroll
- [ ] Listing detail view
- [ ] Search with basic filters
- [ ] Bookmarking (local SwiftData)
- [ ] Pull-to-refresh

### Phase 3: QRZ Integration
- [ ] QRZ Swapmeet scraper (authenticated)
- [ ] Source-aware UI indicators
- [ ] QRZ callsign lookup integration in listing detail

### Phase 4: Notifications + Saved Searches
- [ ] Saved search CRUD
- [ ] Push notification registration
- [ ] New listing matching + APNs delivery
- [ ] Badge counts

### Phase 5: Polish
- [ ] Widget for latest deals
- [ ] Spotlight search integration
- [ ] Share extension
- [ ] iPad layout
