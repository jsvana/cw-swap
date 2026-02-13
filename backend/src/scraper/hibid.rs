use anyhow::{Context, Result};
use chrono::Utc;
use serde::Deserialize;

use crate::models::{AuctionMeta, AuctionStatus, Category, Listing, ListingStatus, Price, Source};

/// HiBid GraphQL client for fetching auction lots
#[derive(Clone)]
pub struct HiBidClient {
    client: reqwest::Client,
    auctioneers: Vec<HiBidAuctioneer>,
}

/// Configuration for a HiBid auctioneer
#[derive(Debug, Clone)]
pub struct HiBidAuctioneer {
    pub subdomain: String,
    pub name: String,
    pub pinned_auction_ids: Vec<i64>,
}

impl Default for HiBidClient {
    fn default() -> Self {
        Self::new()
    }
}

impl HiBidClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .user_agent("CWSwap/1.0 (ham radio classifieds aggregator)")
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .expect("failed to build HTTP client");

        // Default auctioneer: Schulman Auction & Realty
        let auctioneers = vec![HiBidAuctioneer {
            subdomain: "schulmanauction".to_string(),
            name: "Schulman Auction & Realty".to_string(),
            pinned_auction_ids: vec![],
        }];

        Self {
            client,
            auctioneers,
        }
    }

    pub fn with_auctioneers(mut self, auctioneers: Vec<HiBidAuctioneer>) -> Self {
        self.auctioneers = auctioneers;
        self
    }

    /// Search for auction lots
    pub async fn search_lots(
        &self,
        subdomain: &str,
        auction_id: Option<i64>,
        page: i32,
        page_size: i32,
    ) -> Result<Vec<Listing>> {
        let response = self
            .execute_lot_search(subdomain, auction_id, page, page_size)
            .await?;

        let auctioneer = self
            .auctioneers
            .iter()
            .find(|a| a.subdomain == subdomain)
            .context("auctioneer not found")?;

        let mut listings = Vec::new();

        if let Some(results) = response
            .data
            .and_then(|d| d.lot_search)
            .and_then(|ls| ls.paged_results)
            .map(|pr| pr.results)
        {
            for lot in results {
                // Filter out info lots
                if is_info_lot(&lot.lead) {
                    continue;
                }

                if let Some(listing) = self.lot_to_listing(lot, auctioneer) {
                    listings.push(listing);
                }
            }
        }

        Ok(listings)
    }

    /// Discover active auctions for an auctioneer
    pub async fn discover_auctions(&self, subdomain: &str) -> Result<Vec<i64>> {
        let response = self.execute_auction_search(subdomain).await?;

        let auction_ids = response
            .data
            .and_then(|d| d.auction_search)
            .and_then(|s| s.paged_results)
            .map(|pr| pr.results)
            .unwrap_or_default()
            .into_iter()
            .map(|a| a.id)
            .collect();

        Ok(auction_ids)
    }

    /// Execute the LotSearch GraphQL query
    async fn execute_lot_search(
        &self,
        subdomain: &str,
        auction_id: Option<i64>,
        page: i32,
        page_size: i32,
    ) -> Result<LotSearchResponse> {
        let auction_filter = auction_id
            .map(|id| format!(r#", auctionId: {id}"#))
            .unwrap_or_default();

        let query = format!(
            r#"{{
                "query": "query LotSearch($page: Int!, $pageSize: Int!) {{
                    lotSearch(
                        input: {{
                            page: $page,
                            pageSize: $pageSize,
                            countAsView: false
                            {auction_filter}
                        }}
                    ) {{
                        pagedResults {{
                            results {{
                                id
                                lotNumber
                                lead
                                description
                                shippingOffered
                                auction {{
                                    id
                                    title
                                }}
                                lotState {{
                                    bidCount
                                    highBid
                                    minBid
                                    buyNow
                                    status
                                    timeLeftSeconds
                                    timeLeft
                                    isClosed
                                    isLive
                                    isNotYetLive
                                    reserveSatisfied
                                }}
                                featuredPicture {{
                                    thumbnailLocation
                                    fullSizeLocation
                                }}
                            }}
                        }}
                    }}
                }}",
                "variables": {{
                    "page": {page},
                    "pageSize": {page_size}
                }}
            }}"#
        );

        let response = self
            .client
            .post("https://hibid.com/graphql")
            .header("site_subdomain", subdomain.to_uppercase())
            .header("content-type", "application/json")
            .body(query)
            .send()
            .await?
            .json::<LotSearchResponse>()
            .await?;

        Ok(response)
    }

    /// Execute the AuctionSearch GraphQL query
    async fn execute_auction_search(&self, subdomain: &str) -> Result<AuctionSearchResponse> {
        let query = r#"{
            "query": "query AuctionSearch {
                auctionSearch(
                    input: {
                        page: 1,
                        pageSize: 50,
                        showOnlyActive: true
                    }
                ) {
                    pagedResults {
                        results {
                            id
                            title
                        }
                    }
                }
            }"
        }"#;

        let response = self
            .client
            .post("https://hibid.com/graphql")
            .header("site_subdomain", subdomain.to_uppercase())
            .header("content-type", "application/json")
            .body(query)
            .send()
            .await?
            .json::<AuctionSearchResponse>()
            .await?;

        Ok(response)
    }

    /// Convert a HiBid lot to a unified Listing
    fn lot_to_listing(&self, lot: Lot, auctioneer: &HiBidAuctioneer) -> Option<Listing> {
        let lot_state = lot.lot_state.as_ref()?;
        let auction = lot.auction.as_ref()?;

        // Generate URL slug from lead
        let slug = slugify(&lot.lead);
        let source_url = format!(
            "https://{}.hibid.com/lot/{}/{}?auctionId={}",
            auctioneer.subdomain, lot.id, slug, auction.id
        );

        let bid_url = source_url.clone();

        // Determine auction status
        let auction_status = if lot_state.is_closed.unwrap_or(false) {
            AuctionStatus::Closed
        } else if lot_state.is_live.unwrap_or(false) {
            AuctionStatus::Live
        } else if lot_state.is_not_yet_live.unwrap_or(false) {
            AuctionStatus::NotYetLive
        } else if lot_state
            .time_left_seconds
            .map(|s| s < 3600)
            .unwrap_or(false)
        {
            AuctionStatus::Closing
        } else {
            AuctionStatus::Open
        };

        // Calculate closes_at from time_left_seconds
        let closes_at = lot_state
            .time_left_seconds
            .and_then(|s| Utc::now().checked_add_signed(chrono::Duration::seconds(s)));

        let auction_meta = AuctionMeta {
            current_bid: lot_state.high_bid,
            min_bid: lot_state.min_bid,
            bid_count: lot_state.bid_count.unwrap_or(0) as u32,
            high_bid: lot_state.high_bid,
            buy_now: lot_state.buy_now,
            auction_status,
            time_left_seconds: lot_state.time_left_seconds,
            time_left_display: lot_state.time_left.clone(),
            closes_at,
            reserve_met: lot_state.reserve_satisfied,
            lot_number: lot.lot_number.clone(),
            auction_id: auction.id,
            lot_id: lot.id,
            shipping_offered: lot.shipping_offered.unwrap_or(false),
            bid_url,
            auctioneer_name: auctioneer.name.clone(),
        };

        // Use high_bid or min_bid as the price
        let price = lot_state.high_bid.or(lot_state.min_bid).map(|amount| {
            Price {
                amount,
                currency: "USD".to_string(),
                includes_shipping: false,
                obo: false,
            }
        });

        // Collect photo URLs
        let photo_urls = lot
            .featured_picture
            .as_ref()
            .and_then(|p| p.full_size_location.as_ref())
            .map(|url| vec![url.clone()])
            .unwrap_or_default();

        // Determine listing status from auction status
        let status = if auction_status == AuctionStatus::Closed {
            ListingStatus::Sold
        } else {
            ListingStatus::ForSale
        };

        // Try to infer category from title/description
        let category = infer_category(&lot.lead, &lot.description);

        Some(Listing {
            id: format!("hibid-{}-{}", auction.id, lot.id),
            source: Source::HiBid,
            source_url,
            title: lot.lead.clone(),
            description: lot.description.clone(),
            description_html: escape_html(&lot.description),
            status,
            callsign: auctioneer.name.clone(),
            member_id: None,
            avatar_url: None,
            price,
            photo_urls,
            category,
            date_posted: Utc::now(), // HiBid doesn't provide lot posted date
            date_modified: None,
            replies: 0,
            views: 0,
            auction_meta: Some(auction_meta),
        })
    }
}

// GraphQL response types

#[derive(Debug, Deserialize)]
struct LotSearchResponse {
    data: Option<LotSearchData>,
}

#[derive(Debug, Deserialize)]
struct LotSearchData {
    #[serde(rename = "lotSearch")]
    lot_search: Option<LotSearch>,
}

#[derive(Debug, Deserialize)]
struct LotSearch {
    #[serde(rename = "pagedResults")]
    paged_results: Option<PagedResults>,
}

#[derive(Debug, Deserialize)]
struct PagedResults {
    results: Vec<Lot>,
}

#[derive(Debug, Deserialize)]
struct Lot {
    id: i64,
    #[serde(rename = "lotNumber")]
    lot_number: String,
    lead: String,
    description: String,
    #[serde(rename = "shippingOffered")]
    shipping_offered: Option<bool>,
    auction: Option<AuctionInfo>,
    #[serde(rename = "lotState")]
    lot_state: Option<LotState>,
    #[serde(rename = "featuredPicture")]
    featured_picture: Option<Picture>,
}

#[derive(Debug, Deserialize)]
struct AuctionInfo {
    id: i64,
    title: Option<String>,
}

#[derive(Debug, Deserialize)]
struct LotState {
    #[serde(rename = "bidCount")]
    bid_count: Option<i64>,
    #[serde(rename = "highBid")]
    high_bid: Option<f64>,
    #[serde(rename = "minBid")]
    min_bid: Option<f64>,
    #[serde(rename = "buyNow")]
    buy_now: Option<f64>,
    status: Option<String>,
    #[serde(rename = "timeLeftSeconds")]
    time_left_seconds: Option<i64>,
    #[serde(rename = "timeLeft")]
    time_left: Option<String>,
    #[serde(rename = "isClosed")]
    is_closed: Option<bool>,
    #[serde(rename = "isLive")]
    is_live: Option<bool>,
    #[serde(rename = "isNotYetLive")]
    is_not_yet_live: Option<bool>,
    #[serde(rename = "reserveSatisfied")]
    reserve_satisfied: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct Picture {
    #[serde(rename = "thumbnailLocation")]
    thumbnail_location: Option<String>,
    #[serde(rename = "fullSizeLocation")]
    full_size_location: Option<String>,
}

#[derive(Debug, Deserialize)]
struct AuctionSearchResponse {
    data: Option<AuctionSearchData>,
}

#[derive(Debug, Deserialize)]
struct AuctionSearchData {
    #[serde(rename = "auctionSearch")]
    auction_search: Option<AuctionSearch>,
}

#[derive(Debug, Deserialize)]
struct AuctionSearch {
    #[serde(rename = "pagedResults")]
    paged_results: Option<AuctionPagedResults>,
}

#[derive(Debug, Deserialize)]
struct AuctionPagedResults {
    results: Vec<AuctionResult>,
}

#[derive(Debug, Deserialize)]
struct AuctionResult {
    id: i64,
    title: Option<String>,
}

// Helper functions

/// Simple HTML escape
fn escape_html(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}

/// Check if a lot is an info lot (PAYMENT, BIDDING, SHIPPING, etc.)
fn is_info_lot(lead: &str) -> bool {
    let lead_upper = lead.to_uppercase();
    lead_upper.starts_with("PAYMENT")
        || lead_upper.starts_with("BIDDING")
        || lead_upper.starts_with("SHIPPING")
        || lead_upper.starts_with("PICKUP")
        || lead_upper.starts_with("TERMS")
        || lead_upper.starts_with("INFORMATION")
        || lead_upper.starts_with("INFO")
        || lead_upper.starts_with("NOTICE")
        || lead_upper.starts_with("ANNOUNCEMENT")
}

/// Create a URL slug from text
fn slugify(text: &str) -> String {
    text.chars()
        .map(|c| {
            if c.is_alphanumeric() {
                c.to_ascii_lowercase()
            } else {
                '-'
            }
        })
        .collect::<String>()
        .split('-')
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join("-")
}

/// Infer category from title and description
fn infer_category(title: &str, description: &str) -> Option<Category> {
    let text = format!("{} {}", title, description).to_lowercase();

    // Helper to check for word (avoiding "hf" matching in "vhf")
    let has_vhf_uhf = text.contains("vhf") || text.contains("uhf") || text.contains("2m") || text.contains("70cm");
    let has_hf = text.contains(" hf ")
        || text.starts_with("hf ")
        || text.ends_with(" hf")
        || text.contains("yaesu")
        || text.contains("icom")
        || text.contains("kenwood");

    // HF/VHF Radios
    if text.contains("transceiver") || text.contains("xcvr") || text.contains("rig") || text.contains("radio") {
        if has_vhf_uhf {
            return Some(Category::VhfUhfRadios);
        }
        if has_hf {
            return Some(Category::HfRadios);
        }
    }

    // Amplifiers
    if text.contains("amplifier") || text.contains("amp") || text.contains("linear") {
        if has_vhf_uhf {
            return Some(Category::VhfUhfAmplifiers);
        }
        if has_hf {
            return Some(Category::HfAmplifiers);
        }
    }

    // Antennas
    if text.contains("antenna") || text.contains("dipole") || text.contains("beam") || text.contains("yagi") {
        if has_vhf_uhf {
            return Some(Category::VhfUhfAntennas);
        }
        if has_hf {
            return Some(Category::HfAntennas);
        }
    }

    // Towers & Rotators
    if text.contains("tower") {
        return Some(Category::Towers);
    }
    if text.contains("rotator") || text.contains("rotor") {
        return Some(Category::Rotators);
    }

    // Keys
    if text.contains("key") || text.contains("keyer") || text.contains("paddle") {
        return Some(Category::Keys);
    }

    // Test Equipment
    if text.contains("analyzer") || text.contains("meter") || text.contains("scope") || text.contains("multimeter") {
        return Some(Category::TestEquipment);
    }

    // Antique Radios
    if text.contains("antique") || text.contains("vintage") || text.contains("tube") {
        return Some(Category::AntiqueRadios);
    }

    // Default to Miscellaneous
    Some(Category::Miscellaneous)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_info_lot() {
        assert!(is_info_lot("PAYMENT INFORMATION"));
        assert!(is_info_lot("BIDDING INSTRUCTIONS"));
        assert!(is_info_lot("SHIPPING & HANDLING"));
        assert!(!is_info_lot("Yaesu FT-991A HF/VHF/UHF Transceiver"));
    }

    #[test]
    fn test_slugify() {
        assert_eq!(slugify("Yaesu FT-991A"), "yaesu-ft-991a");
        assert_eq!(slugify("Test  Multiple   Spaces"), "test-multiple-spaces");
        assert_eq!(slugify("Special!@#$%Chars"), "special-chars");
    }

    #[test]
    fn test_infer_category() {
        assert_eq!(
            infer_category("Yaesu FT-991A HF Transceiver", ""),
            Some(Category::HfRadios)
        );
        assert_eq!(
            infer_category("2m VHF Radio", "Baofeng UV-5R"),
            Some(Category::VhfUhfRadios)
        );
        assert_eq!(
            infer_category("HF Beam Antenna", ""),
            Some(Category::HfAntennas)
        );
    }
}
