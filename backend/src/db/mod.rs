use anyhow::Result;
use chrono::Utc;
use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;

use crate::models::{Category, CategoryInfo, Listing, ListingStatus, ListingsPage};

pub async fn connect(database_url: &str) -> Result<PgPool> {
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(database_url)
        .await?;
    Ok(pool)
}

pub async fn run_migrations(pool: &PgPool) -> Result<()> {
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS listings (
            id TEXT PRIMARY KEY,
            source TEXT NOT NULL,
            source_url TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            description_html TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL DEFAULT 'for_sale',
            callsign TEXT NOT NULL,
            member_id BIGINT,
            avatar_url TEXT,
            price_amount DOUBLE PRECISION,
            price_currency TEXT,
            price_includes_shipping BOOLEAN,
            price_obo BOOLEAN,
            photo_urls TEXT[] NOT NULL DEFAULT '{}',
            category TEXT,
            date_posted TIMESTAMPTZ NOT NULL,
            date_modified TIMESTAMPTZ,
            replies INTEGER NOT NULL DEFAULT 0,
            views INTEGER NOT NULL DEFAULT 0,
            auction_meta_json TEXT,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_listings_source ON listings(source)",
    )
    .execute(pool)
    .await?;

    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status)",
    )
    .execute(pool)
    .await?;

    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_listings_category ON listings(category)",
    )
    .execute(pool)
    .await?;

    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_listings_callsign ON listings(callsign)",
    )
    .execute(pool)
    .await?;

    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_listings_date_posted ON listings(date_posted DESC)",
    )
    .execute(pool)
    .await?;

    // Full-text search index
    sqlx::query(
        r#"
        CREATE INDEX IF NOT EXISTS idx_listings_fts ON listings
        USING gin(to_tsvector('english', title || ' ' || description))
        "#,
    )
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn upsert_listing(pool: &PgPool, listing: &Listing) -> Result<()> {
    let photo_urls: Vec<&str> = listing.photo_urls.iter().map(|s| s.as_str()).collect();
    let auction_meta_json = listing
        .auction_meta
        .as_ref()
        .and_then(|m| serde_json::to_string(m).ok());

    sqlx::query(
        r#"
        INSERT INTO listings (
            id, source, source_url, title, description, description_html,
            status, callsign, member_id, avatar_url,
            price_amount, price_currency, price_includes_shipping, price_obo,
            photo_urls, category, date_posted, date_modified, replies, views,
            auction_meta_json,
            updated_at
        ) VALUES (
            $1, $2, $3, $4, $5, $6,
            $7, $8, $9, $10,
            $11, $12, $13, $14,
            $15, $16, $17, $18, $19, $20,
            $21,
            NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            title = EXCLUDED.title,
            description = EXCLUDED.description,
            description_html = EXCLUDED.description_html,
            status = EXCLUDED.status,
            price_amount = EXCLUDED.price_amount,
            price_currency = EXCLUDED.price_currency,
            price_includes_shipping = EXCLUDED.price_includes_shipping,
            price_obo = EXCLUDED.price_obo,
            photo_urls = EXCLUDED.photo_urls,
            date_modified = EXCLUDED.date_modified,
            replies = EXCLUDED.replies,
            views = EXCLUDED.views,
            auction_meta_json = EXCLUDED.auction_meta_json,
            updated_at = NOW()
        "#,
    )
    .bind(&listing.id)
    .bind(listing.source.to_string())
    .bind(&listing.source_url)
    .bind(&listing.title)
    .bind(&listing.description)
    .bind(&listing.description_html)
    .bind(listing.status.to_string())
    .bind(&listing.callsign)
    .bind(listing.member_id)
    .bind(&listing.avatar_url)
    .bind(listing.price.as_ref().map(|p| p.amount))
    .bind(listing.price.as_ref().map(|p| p.currency.as_str()))
    .bind(listing.price.as_ref().map(|p| p.includes_shipping))
    .bind(listing.price.as_ref().map(|p| p.obo))
    .bind(&photo_urls)
    .bind(listing.category.map(|c| format!("{c:?}")))
    .bind(listing.date_posted)
    .bind(listing.date_modified)
    .bind(listing.replies)
    .bind(listing.views)
    .bind(auction_meta_json)
    .execute(pool)
    .await?;

    Ok(())
}

#[derive(Debug, Default)]
pub struct ListingQuery {
    pub source: Option<String>,
    pub category: Option<String>,
    pub status: Option<String>,
    pub callsign: Option<String>,
    pub q: Option<String>,
    pub price_min: Option<f64>,
    pub price_max: Option<f64>,
    pub has_photo: Option<bool>,
    pub sort: Option<String>,
    pub page: i32,
    pub per_page: i32,
    pub listing_type: Option<String>,
}

pub async fn query_listings(pool: &PgPool, query: &ListingQuery) -> Result<ListingsPage> {
    let offset = (query.page - 1) * query.per_page;

    // Build dynamic WHERE clauses
    let mut conditions = vec!["1=1".to_string()];
    let mut param_idx = 0u32;

    // We'll use a simpler approach: build the full query string with placeholders
    // then bind parameters in order
    if query.source.is_some() {
        param_idx += 1;
        conditions.push(format!("source = ${param_idx}"));
    }
    if query.category.is_some() {
        param_idx += 1;
        conditions.push(format!("category = ${param_idx}"));
    }
    if query.status.is_some() {
        param_idx += 1;
        conditions.push(format!("status = ${param_idx}"));
    }
    if query.callsign.is_some() {
        param_idx += 1;
        conditions.push(format!("callsign ILIKE ${param_idx}"));
    }
    if query.q.is_some() {
        param_idx += 1;
        conditions.push(format!(
            "to_tsvector('english', title || ' ' || description) @@ plainto_tsquery('english', ${param_idx})"
        ));
    }
    if query.price_min.is_some() {
        param_idx += 1;
        conditions.push(format!("price_amount >= ${param_idx}"));
    }
    if query.price_max.is_some() {
        param_idx += 1;
        conditions.push(format!("price_amount <= ${param_idx}"));
    }
    if query.has_photo == Some(true) {
        conditions.push("array_length(photo_urls, 1) > 0".to_string());
    }
    if let Some(ref listing_type) = query.listing_type {
        match listing_type.to_lowercase().as_str() {
            "auction" => {
                conditions.push("auction_meta_json IS NOT NULL".to_string());
            }
            "sale" | "for_sale" => {
                conditions.push("auction_meta_json IS NULL".to_string());
            }
            _ => {}
        }
    }

    let where_clause = conditions.join(" AND ");

    let order_by = match query.sort.as_deref() {
        Some("oldest") => "date_posted ASC",
        Some("price_asc") => "price_amount ASC NULLS LAST",
        Some("price_desc") => "price_amount DESC NULLS LAST",
        Some("closing_soon") => {
            // For auctions, parse closes_at from JSON and sort by it
            "CAST(auction_meta_json::json->>'closes_at' AS TIMESTAMPTZ) ASC NULLS LAST"
        }
        _ => "date_posted DESC",
    };

    let count_idx_offset = param_idx;
    let limit_param = count_idx_offset + 1;
    let offset_param = count_idx_offset + 2;

    let count_sql = format!("SELECT COUNT(*) as count FROM listings WHERE {where_clause}");
    let list_sql = format!(
        "SELECT * FROM listings WHERE {where_clause} ORDER BY {order_by} LIMIT ${limit_param} OFFSET ${offset_param}"
    );

    // Build count query
    let mut count_query = sqlx::query_scalar::<_, i64>(&count_sql);
    if let Some(ref v) = query.source {
        count_query = count_query.bind(v);
    }
    if let Some(ref v) = query.category {
        count_query = count_query.bind(v);
    }
    if let Some(ref v) = query.status {
        count_query = count_query.bind(v);
    }
    if let Some(ref v) = query.callsign {
        count_query = count_query.bind(v);
    }
    if let Some(ref v) = query.q {
        count_query = count_query.bind(v);
    }
    if let Some(v) = query.price_min {
        count_query = count_query.bind(v);
    }
    if let Some(v) = query.price_max {
        count_query = count_query.bind(v);
    }

    let total = count_query.fetch_one(pool).await?;

    // Build list query
    let mut list_query = sqlx::query_as::<_, ListingRow>(&list_sql);
    if let Some(ref v) = query.source {
        list_query = list_query.bind(v);
    }
    if let Some(ref v) = query.category {
        list_query = list_query.bind(v);
    }
    if let Some(ref v) = query.status {
        list_query = list_query.bind(v);
    }
    if let Some(ref v) = query.callsign {
        list_query = list_query.bind(v);
    }
    if let Some(ref v) = query.q {
        list_query = list_query.bind(v);
    }
    if let Some(v) = query.price_min {
        list_query = list_query.bind(v);
    }
    if let Some(v) = query.price_max {
        list_query = list_query.bind(v);
    }
    list_query = list_query.bind(query.per_page as i64);
    list_query = list_query.bind(offset as i64);

    let rows = list_query.fetch_all(pool).await?;
    let listings: Vec<Listing> = rows.into_iter().map(|r| r.into_listing()).collect();
    let has_more = (offset + query.per_page) < total as i32;

    Ok(ListingsPage {
        listings,
        total,
        page: query.page,
        per_page: query.per_page,
        has_more,
    })
}

pub async fn get_listing(pool: &PgPool, id: &str) -> Result<Option<Listing>> {
    let row = sqlx::query_as::<_, ListingRow>("SELECT * FROM listings WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await?;
    Ok(row.map(|r| r.into_listing()))
}

pub async fn get_categories(pool: &PgPool) -> Result<Vec<CategoryInfo>> {
    let rows = sqlx::query_as::<_, CategoryCountRow>(
        "SELECT category, COUNT(*) as count FROM listings WHERE category IS NOT NULL GROUP BY category ORDER BY count DESC",
    )
    .fetch_all(pool)
    .await?;

    let mut categories: Vec<CategoryInfo> = Category::all()
        .iter()
        .map(|cat| {
            let count = rows
                .iter()
                .find(|r| r.category.as_deref() == Some(&format!("{cat:?}")))
                .map(|r| r.count)
                .unwrap_or(0);
            CategoryInfo {
                category: *cat,
                display_name: cat.display_name().to_string(),
                sf_symbol: cat.sf_symbol().to_string(),
                listing_count: count,
            }
        })
        .collect();

    categories.sort_by(|a, b| b.listing_count.cmp(&a.listing_count));
    Ok(categories)
}

#[derive(sqlx::FromRow)]
struct ListingRow {
    id: String,
    source: String,
    source_url: String,
    title: String,
    description: String,
    description_html: String,
    status: String,
    callsign: String,
    member_id: Option<i64>,
    avatar_url: Option<String>,
    price_amount: Option<f64>,
    price_currency: Option<String>,
    price_includes_shipping: Option<bool>,
    price_obo: Option<bool>,
    photo_urls: Vec<String>,
    category: Option<String>,
    date_posted: chrono::DateTime<Utc>,
    date_modified: Option<chrono::DateTime<Utc>>,
    replies: i32,
    views: i32,
    auction_meta_json: Option<String>,
    #[allow(dead_code)]
    created_at: chrono::DateTime<Utc>,
    #[allow(dead_code)]
    updated_at: chrono::DateTime<Utc>,
}

impl ListingRow {
    fn into_listing(self) -> Listing {
        use crate::models::{AuctionMeta, Price, Source};
        let source = self.source.parse::<Source>().unwrap_or(Source::Qrz);
        let status = self.status.parse::<ListingStatus>().unwrap_or(ListingStatus::ForSale);
        let price = self.price_amount.map(|amount| Price {
            amount,
            currency: self.price_currency.unwrap_or_else(|| "USD".to_string()),
            includes_shipping: self.price_includes_shipping.unwrap_or(false),
            obo: self.price_obo.unwrap_or(false),
        });

        let auction_meta = self
            .auction_meta_json
            .as_ref()
            .and_then(|json| serde_json::from_str::<AuctionMeta>(json).ok());

        Listing {
            id: self.id,
            source,
            source_url: self.source_url,
            title: self.title,
            description: self.description,
            description_html: self.description_html,
            status,
            callsign: self.callsign,
            member_id: self.member_id,
            avatar_url: self.avatar_url,
            price,
            photo_urls: self.photo_urls,
            category: None, // TODO: parse from string
            date_posted: self.date_posted,
            date_modified: self.date_modified,
            replies: self.replies,
            views: self.views,
            auction_meta,
        }
    }
}

#[derive(sqlx::FromRow)]
struct CategoryCountRow {
    category: Option<String>,
    count: i64,
}
