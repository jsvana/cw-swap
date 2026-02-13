use anyhow::{Context, Result};
use chrono::{TimeZone, Utc};
use scraper::{Html, Selector};
use tracing::warn;

use crate::models::{Listing, ListingStatus, Source};
use crate::scraper::price_extractor::extract_price;

const QRZ_BASE: &str = "https://forums.qrz.com/index.php";

pub struct QrzScraper {
    client: reqwest::Client,
}

/// A minimal thread entry from the forum listing page
#[derive(Debug)]
pub(crate) struct ThreadEntry {
    pub thread_id: i64,
    pub title: String,
    pub url: String,
    pub replies: i32,
    pub views: i32,
    pub is_sticky: bool,
}

impl QrzScraper {
    pub fn new(client: reqwest::Client) -> Self {
        Self { client }
    }

    /// Log in to QRZ. Must be called before scraping if the forum requires auth.
    /// Logs in via the main QRZ site, then also logs into the forums if needed.
    pub async fn login(&self, username: &str, password: &str) -> Result<()> {
        // Step 1: Log in to the main QRZ site
        let login_page = self
            .client
            .get("https://www.qrz.com/login")
            .send()
            .await
            .context("failed to fetch QRZ login page")?
            .text()
            .await
            .context("failed to read QRZ login page body")?;

        tracing::debug!(body_len = login_page.len(), "fetched QRZ login page");
        // Log first 500 chars to see what we got
        tracing::debug!(
            body_preview = &login_page[..login_page.len().min(500)],
            "login page preview"
        );

        // Try to find a CSRF token on the main site login page
        let token = extract_hidden_input(&login_page, "_token")
            .or_else(|| extract_hidden_input(&login_page, "_xfToken"));
        tracing::debug!(has_token = token.is_some(), "CSRF token search");

        let mut form = vec![
            ("username".to_string(), username.to_string()),
            ("password".to_string(), password.to_string()),
        ];
        if let Some(ref tok) = token {
            form.push(("_token".to_string(), tok.clone()));
        }

        tracing::debug!("posting login to www.qrz.com...");

        let resp = self
            .client
            .post("https://www.qrz.com/login")
            .form(&form)
            .send()
            .await
            .context("failed to post QRZ login")?;

        let status = resp.status();
        let body = resp.text().await.context("failed to read login response")?;
        tracing::debug!(status = %status, body_len = body.len(), "main site login response");

        if body.contains("Incorrect password")
            || body.contains("Invalid credentials")
            || body.contains("These credentials do not match")
        {
            anyhow::bail!("QRZ login failed: incorrect username or password");
        }

        // Step 2: Also log into the forums (XenForo) in case cookies don't carry over
        tracing::debug!("logging into QRZ forums...");
        let forums_login_page = self
            .client
            .get(format!("{QRZ_BASE}?login/"))
            .send()
            .await
            .context("failed to fetch forums login page")?
            .text()
            .await
            .context("failed to read forums login page body")?;

        // If we're already logged in (cookies worked), the page won't have a login form
        if let Some(xf_token) = extract_xf_token(&forums_login_page) {
            tracing::debug!("got XenForo CSRF token, posting forums login...");
            let resp = self
                .client
                .post(format!("{QRZ_BASE}?login/login"))
                .form(&[
                    ("login", username),
                    ("password", password),
                    ("_xfToken", &xf_token),
                    ("remember", "1"),
                ])
                .send()
                .await
                .context("failed to post forums login")?;

            let status = resp.status();
            tracing::debug!(status = %status, "forums login response");
        } else {
            tracing::debug!("no XenForo login form found — may already be logged in via SSO");
        }

        tracing::info!("QRZ login complete");
        Ok(())
    }

    /// Scrape a page of thread listings from the QRZ Swapmeet forum
    pub async fn scrape_listing_page(&self, page: u32) -> Result<Vec<ThreadEntry>> {
        let url = format!(
            "{QRZ_BASE}?forums/ham-radio-gear-for-sale.7/page-{page}"
        );
        tracing::debug!(%url, "fetching listing page");
        let resp = self
            .client
            .get(&url)
            .send()
            .await
            .context("failed to fetch listing page")?;
        let status = resp.status();
        let html = resp
            .text()
            .await
            .context("failed to read listing page body")?;

        tracing::debug!(
            status = %status,
            body_len = html.len(),
            "listing page response"
        );

        // Save live HTML for debugging
        if let Err(e) = std::fs::write("/tmp/qrz_live_listing.html", &html) {
            tracing::warn!(error = %e, "could not save debug HTML");
        } else {
            tracing::debug!("saved listing page HTML to /tmp/qrz_live_listing.html");
        }

        parse_listing_page(&html)
    }

    /// Scrape a single thread detail page to get the full listing
    pub async fn scrape_thread(&self, thread_id: i64, slug: &str) -> Result<Listing> {
        let url = format!("{QRZ_BASE}?threads/{slug}.{thread_id}/");
        let html = self
            .client
            .get(&url)
            .send()
            .await
            .context("failed to fetch thread")?
            .text()
            .await
            .context("failed to read thread body")?;

        parse_thread_detail(&html, thread_id, &url)
    }

    /// Convenience: scrape a page and then fetch full details for each non-sticky thread
    pub async fn scrape_full_page(&self, page: u32) -> Result<Vec<Listing>> {
        let entries = self.scrape_listing_page(page).await?;
        let mut listings = Vec::new();

        for entry in entries {
            if entry.is_sticky {
                continue;
            }
            let slug = slug_from_url(&entry.url);
            match self.scrape_thread(entry.thread_id, &slug).await {
                Ok(mut listing) => {
                    listing.replies = entry.replies;
                    listing.views = entry.views;
                    listings.push(listing);
                }
                Err(e) => {
                    warn!(thread_id = entry.thread_id, error = %e, "failed to scrape thread detail");
                }
            }
            // Rate limit: 1 req/sec
            tokio::time::sleep(std::time::Duration::from_secs(1)).await;
        }

        Ok(listings)
    }
}

fn slug_from_url(url: &str) -> String {
    // URL pattern: index.php?threads/{slug}.{id}/
    // or full URL: https://forums.qrz.com/index.php?threads/{slug}.{id}/
    if let Some(threads_part) = url.split("threads/").nth(1) {
        if let Some(dot_pos) = threads_part.rfind('.') {
            return threads_part[..dot_pos].to_string();
        }
    }
    String::new()
}

pub fn parse_listing_page(html: &str) -> Result<Vec<ThreadEntry>> {
    let document = Html::parse_document(html);

    let thread_sel = Selector::parse("li.discussionListItem").unwrap();
    // Use a.PreviewTooltip to get the actual title link, NOT the prefix link
    let title_sel = Selector::parse("h3.title a.PreviewTooltip").unwrap();
    let date_sel = Selector::parse("abbr.DateTime").unwrap();
    let major_sel = Selector::parse("dl.major dd").unwrap();
    let minor_sel = Selector::parse("dl.minor dd").unwrap();

    let thread_count = document.select(&thread_sel).count();
    tracing::debug!(thread_count, "found discussionListItem elements");

    if thread_count == 0 {
        // Try alternate selectors to diagnose the structure
        let alt_selectors = [
            "li[id^=\"thread-\"]",
            ".discussionListItem",
            ".discussionList .discussionListItem",
            "ol.discussionListItems > li",
            ".structItem",
            ".structItemContainer .structItem",
        ];
        for sel_str in &alt_selectors {
            if let Ok(sel) = Selector::parse(sel_str) {
                let count = document.select(&sel).count();
                if count > 0 {
                    tracing::info!(selector = sel_str, count, "alternate selector matched!");
                }
            }
        }
    }

    let mut entries = Vec::new();

    for thread_el in document.select(&thread_sel) {
        // Thread ID from id="thread-{id}" attribute
        let thread_id = thread_el
            .value()
            .id()
            .and_then(|id| id.strip_prefix("thread-"))
            .and_then(|id| id.parse::<i64>().ok())
            .unwrap_or(0);

        if thread_id == 0 {
            continue;
        }

        // Title and URL from the PreviewTooltip link (skips prefix link)
        let (title, url) = if let Some(title_el) = thread_el.select(&title_sel).next() {
            let text = title_el.text().collect::<String>().trim().to_string();
            let href = title_el.value().attr("href").unwrap_or("").to_string();
            (text, href)
        } else {
            // Fallback: try any link in h3.title that has an href containing "threads/"
            let fallback_sel = Selector::parse("h3.title a[href*=\"threads/\"]").unwrap();
            if let Some(title_el) = thread_el.select(&fallback_sel).next() {
                let text = title_el.text().collect::<String>().trim().to_string();
                let href = title_el.value().attr("href").unwrap_or("").to_string();
                (text, href)
            } else {
                continue;
            }
        };

        // Date posted (unix timestamp)
        let _date_posted = thread_el.select(&date_sel).next().and_then(|el| {
            el.value()
                .attr("data-time")
                .and_then(|t| t.parse::<i64>().ok())
                .and_then(|ts| Utc.timestamp_opt(ts, 0).single())
        });

        // Replies (dl.major > dd)
        let replies = thread_el
            .select(&major_sel)
            .next()
            .map(|el| {
                el.text()
                    .collect::<String>()
                    .trim()
                    .replace(',', "")
                    .parse::<i32>()
                    .unwrap_or(0)
            })
            .unwrap_or(0);

        // Views (dl.minor > dd)
        let views = thread_el
            .select(&minor_sel)
            .next()
            .map(|el| {
                el.text()
                    .collect::<String>()
                    .trim()
                    .replace(',', "")
                    .parse::<i32>()
                    .unwrap_or(0)
            })
            .unwrap_or(0);

        let is_sticky = thread_el
            .value()
            .attr("class")
            .map(|c| c.contains("sticky"))
            .unwrap_or(false);

        entries.push(ThreadEntry {
            thread_id,
            title,
            url,
            replies,
            views,
            is_sticky,
        });
    }

    Ok(entries)
}

pub fn parse_thread_detail(html: &str, thread_id: i64, source_url: &str) -> Result<Listing> {
    let document = Html::parse_document(html);

    let h1_sel = Selector::parse("h1").unwrap();
    let prefix_sel = Selector::parse("span.prefix").unwrap();
    // Posts use id="post-{id}" with class "message"
    let msg_sel = Selector::parse("li.message").unwrap();
    let msg_text_sel = Selector::parse("blockquote.messageText").unwrap();
    let avatar_sel = Selector::parse("div.messageUserBlock img").unwrap();
    // Full-size image URLs are on the parent <a class="LbTrigger"> href
    let lb_trigger_sel = Selector::parse("a.LbTrigger").unwrap();
    let img_sel = Selector::parse("img.bbCodeImage").unwrap();
    let date_sel = Selector::parse("abbr.DateTime").unwrap();
    let member_sel = Selector::parse("a[href*=\"members/\"]").unwrap();
    let edit_date_sel = Selector::parse("div.editDate abbr.DateTime").unwrap();

    // Parse title from <h1>
    let title_el = document.select(&h1_sel).next().context("no h1 found")?;
    let full_title = title_el.text().collect::<String>().trim().to_string();

    // Parse prefix/status from <span class="prefix"> inside <h1>
    let prefix_text = title_el
        .select(&prefix_sel)
        .next()
        .map(|el| el.text().collect::<String>().trim().to_string());

    let status = match prefix_text.as_deref() {
        Some("SOLD") => ListingStatus::Sold,
        Some("Canceled") => ListingStatus::Canceled,
        _ => ListingStatus::ForSale,
    };

    // Strip prefix from title (e.g. "For Sale Yaesu FTX-1 Optima" -> "Yaesu FTX-1 Optima")
    let title = if let Some(prefix) = &prefix_text {
        full_title
            .strip_prefix(prefix)
            .unwrap_or(&full_title)
            .trim_start_matches(" - ")
            .trim()
            .to_string()
    } else {
        full_title
    };

    // First message (post) is the listing content
    let first_msg = document.select(&msg_sel).next().context("no messages found")?;

    let callsign = first_msg
        .value()
        .attr("data-author")
        .unwrap_or("")
        .to_string();

    // Description HTML and plain text
    let description_html = first_msg
        .select(&msg_text_sel)
        .next()
        .map(|el| el.inner_html())
        .unwrap_or_default();

    let description = first_msg
        .select(&msg_text_sel)
        .next()
        .map(|el| el.text().collect::<String>().trim().to_string())
        .unwrap_or_default();

    // Avatar URL
    let avatar_url = first_msg
        .select(&avatar_sel)
        .next()
        .and_then(|el| el.value().attr("src").map(|s| resolve_url(s)));

    // Images: prefer full-size from LbTrigger href, fall back to img src
    let mut photo_urls: Vec<String> = first_msg
        .select(&lb_trigger_sel)
        .filter_map(|el| el.value().attr("href").map(|s| resolve_url(s)))
        .collect();

    if photo_urls.is_empty() {
        photo_urls = first_msg
            .select(&img_sel)
            .filter_map(|el| el.value().attr("src").map(|s| resolve_url(s)))
            .collect();
    }

    // Post date from first message
    let date_posted = first_msg
        .select(&date_sel)
        .next()
        .and_then(|el| {
            el.value()
                .attr("data-time")
                .and_then(|t| t.parse::<i64>().ok())
                .and_then(|ts| Utc.timestamp_opt(ts, 0).single())
        })
        .unwrap_or_else(Utc::now);

    // Last edited date
    let date_modified = first_msg.select(&edit_date_sel).next().and_then(|el| {
        el.value()
            .attr("data-time")
            .and_then(|t| t.parse::<i64>().ok())
            .and_then(|ts| Utc.timestamp_opt(ts, 0).single())
    });

    // Member ID from member link
    let member_id = first_msg.select(&member_sel).next().and_then(|el| {
        el.value().attr("href").and_then(|href| {
            // Pattern: members/{call}.{id}/
            href.split('.').last()?.trim_end_matches('/').parse::<i64>().ok()
        })
    });

    // Extract price from description
    let price = extract_price(&description);

    Ok(Listing {
        id: format!("qrz:{thread_id}"),
        source: Source::Qrz,
        source_url: source_url.to_string(),
        title,
        description,
        description_html,
        status,
        callsign,
        member_id,
        avatar_url,
        price,
        photo_urls,
        category: None,
        date_posted,
        date_modified,
        replies: 0,
        views: 0,
        auction_meta: None,
    })
}

/// Extract a XenForo `_xfToken` from a page's HTML
fn extract_xf_token(html: &str) -> Option<String> {
    extract_hidden_input(html, "_xfToken")
}

/// Extract the value of a hidden input field by name
fn extract_hidden_input(html: &str, name: &str) -> Option<String> {
    let document = Html::parse_document(html);
    let selector =
        Selector::parse(&format!("input[name=\"{name}\"][type=\"hidden\"]")).ok()?;
    document
        .select(&selector)
        .next()
        .and_then(|el| el.value().attr("value").map(|s| s.to_string()))
}

fn resolve_url(url: &str) -> String {
    if url.starts_with("http") {
        url.to_string()
    } else {
        format!("https://forums.qrz.com/{}", url.trim_start_matches('/'))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_slug_from_url() {
        assert_eq!(
            slug_from_url("index.php?threads/yaesu-ftx-1-optima.980690/"),
            "yaesu-ftx-1-optima"
        );
        assert_eq!(
            slug_from_url("https://forums.qrz.com/index.php?threads/some-radio.12345/"),
            "some-radio"
        );
    }

    #[test]
    fn test_parse_listing_page() {
        let html = std::fs::read_to_string("../qrz_sources/items.php")
            .expect("need qrz_sources/items.php for test");
        let entries = parse_listing_page(&html).unwrap();

        assert!(!entries.is_empty(), "should parse at least one thread");

        // First two should be sticky
        assert!(entries[0].is_sticky, "first entry should be sticky");
        assert!(entries[1].is_sticky, "second entry should be sticky");

        // Find the known thread
        let optima = entries.iter().find(|e| e.thread_id == 980690);
        assert!(optima.is_some(), "should find thread 980690");
        let optima = optima.unwrap();
        assert_eq!(optima.title, "Yaesu FTX-1 Optima");
        assert!(
            optima.url.contains("threads/yaesu-ftx-1-optima.980690"),
            "URL should contain thread slug: {}",
            optima.url
        );

        // Non-sticky entries should have valid titles (not "For Sale" prefix text)
        for entry in entries.iter().filter(|e| !e.is_sticky) {
            assert!(
                !entry.title.is_empty(),
                "thread {} should have a title",
                entry.thread_id
            );
            assert!(
                entry.title != "For Sale" && entry.title != "SOLD",
                "thread {} title should not be just the prefix: '{}'",
                entry.thread_id,
                entry.title
            );
        }
    }

    #[test]
    fn test_parse_thread_detail() {
        let html = std::fs::read_to_string("../qrz_sources/item_for_sale.php")
            .expect("need qrz_sources/item_for_sale.php for test");
        let listing = parse_thread_detail(&html, 980690, "https://forums.qrz.com/index.php?threads/yaesu-ftx-1-optima.980690/").unwrap();

        assert_eq!(listing.id, "qrz:980690");
        assert_eq!(listing.title, "Yaesu FTX-1 Optima");
        assert_eq!(listing.callsign, "WM7C");
        assert_eq!(listing.status, ListingStatus::ForSale);
        assert!(!listing.description.is_empty());
        assert!(listing.description.contains("1650"), "description should mention price");

        // Price extraction
        let price = listing.price.as_ref().expect("should extract price");
        assert!((price.amount - 1650.0).abs() < f64::EPSILON);
        assert!(price.includes_shipping);

        // Photos
        assert!(!listing.photo_urls.is_empty(), "should have at least one photo");
        assert!(
            listing.photo_urls[0].starts_with("https://"),
            "photo URL should be absolute: {}",
            listing.photo_urls[0]
        );

        // Avatar
        assert!(listing.avatar_url.is_some());

        // Member ID
        assert_eq!(listing.member_id, Some(368068));

        // Date modified should be present (the listing was edited)
        assert!(listing.date_modified.is_some());
    }
}
