use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use super::Price;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Source {
    Qrz,
    Qth,
    HiBid,
}

impl std::fmt::Display for Source {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Source::Qrz => write!(f, "qrz"),
            Source::Qth => write!(f, "qth"),
            Source::HiBid => write!(f, "hibid"),
        }
    }
}

impl std::str::FromStr for Source {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "qrz" => Ok(Source::Qrz),
            "qth" => Ok(Source::Qth),
            "hibid" => Ok(Source::HiBid),
            _ => Err(format!("unknown source: {s}")),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ListingType {
    ForSale,
    Wanted,
    Trade,
    Auction,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ListingStatus {
    ForSale,
    Sold,
    Canceled,
}

impl std::fmt::Display for ListingStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ListingStatus::ForSale => write!(f, "for_sale"),
            ListingStatus::Sold => write!(f, "sold"),
            ListingStatus::Canceled => write!(f, "canceled"),
        }
    }
}

impl std::str::FromStr for ListingStatus {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "for_sale" | "for sale" => Ok(ListingStatus::ForSale),
            "sold" => Ok(ListingStatus::Sold),
            "canceled" | "cancelled" => Ok(ListingStatus::Canceled),
            _ => Err(format!("unknown status: {s}")),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Category {
    HfRadios,
    VhfUhfRadios,
    HfAmplifiers,
    VhfUhfAmplifiers,
    HfAntennas,
    VhfUhfAntennas,
    Towers,
    Rotators,
    Keys,
    TestEquipment,
    Computers,
    AntiqueRadios,
    Accessories,
    Miscellaneous,
}

impl Category {
    pub fn all() -> &'static [Category] {
        &[
            Category::HfRadios,
            Category::VhfUhfRadios,
            Category::HfAmplifiers,
            Category::VhfUhfAmplifiers,
            Category::HfAntennas,
            Category::VhfUhfAntennas,
            Category::Towers,
            Category::Rotators,
            Category::Keys,
            Category::TestEquipment,
            Category::Computers,
            Category::AntiqueRadios,
            Category::Accessories,
            Category::Miscellaneous,
        ]
    }

    pub fn display_name(&self) -> &'static str {
        match self {
            Category::HfRadios => "HF Radios",
            Category::VhfUhfRadios => "VHF/UHF Radios",
            Category::HfAmplifiers => "HF Amplifiers",
            Category::VhfUhfAmplifiers => "VHF/UHF Amplifiers",
            Category::HfAntennas => "HF Antennas",
            Category::VhfUhfAntennas => "VHF/UHF Antennas",
            Category::Towers => "Towers",
            Category::Rotators => "Rotators",
            Category::Keys => "Keys & Keyers",
            Category::TestEquipment => "Test Equipment",
            Category::Computers => "Computers",
            Category::AntiqueRadios => "Antique Radios",
            Category::Accessories => "Accessories",
            Category::Miscellaneous => "Miscellaneous",
        }
    }

    pub fn sf_symbol(&self) -> &'static str {
        match self {
            Category::HfRadios => "radio",
            Category::VhfUhfRadios => "antenna.radiowaves.left.and.right",
            Category::HfAmplifiers => "bolt.fill",
            Category::VhfUhfAmplifiers => "bolt.fill",
            Category::HfAntennas => "antenna.radiowaves.left.and.right",
            Category::VhfUhfAntennas => "antenna.radiowaves.left.and.right",
            Category::Towers => "building.2",
            Category::Rotators => "arrow.triangle.2.circlepath",
            Category::Keys => "pianokeys",
            Category::TestEquipment => "waveform",
            Category::Computers => "desktopcomputer",
            Category::AntiqueRadios => "clock.arrow.circlepath",
            Category::Accessories => "wrench.and.screwdriver",
            Category::Miscellaneous => "ellipsis.circle",
        }
    }
}

impl std::fmt::Display for Category {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.display_name())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AuctionStatus {
    Open,
    Closing,
    Closed,
    NotYetLive,
    Live,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuctionMeta {
    pub current_bid: Option<f64>,
    pub min_bid: Option<f64>,
    pub bid_count: u32,
    pub high_bid: Option<f64>,
    pub buy_now: Option<f64>,
    pub auction_status: AuctionStatus,
    pub time_left_seconds: Option<i64>,
    pub time_left_display: Option<String>,
    pub closes_at: Option<DateTime<Utc>>,
    pub reserve_met: Option<bool>,
    pub lot_number: String,
    pub auction_id: i64,
    pub lot_id: i64,
    pub shipping_offered: bool,
    pub bid_url: String,
    pub auctioneer_name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Listing {
    pub id: String,
    pub source: Source,
    pub source_url: String,
    pub title: String,
    pub description: String,
    pub description_html: String,
    pub status: ListingStatus,
    pub callsign: String,
    pub member_id: Option<i64>,
    pub avatar_url: Option<String>,
    pub price: Option<Price>,
    pub photo_urls: Vec<String>,
    pub category: Option<Category>,
    pub date_posted: DateTime<Utc>,
    pub date_modified: Option<DateTime<Utc>>,
    pub replies: i32,
    pub views: i32,
    pub auction_meta: Option<AuctionMeta>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ListingsPage {
    pub listings: Vec<Listing>,
    pub total: i64,
    pub page: i32,
    pub per_page: i32,
    pub has_more: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryInfo {
    pub category: Category,
    pub display_name: String,
    pub sf_symbol: String,
    pub listing_count: i64,
}
